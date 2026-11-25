import CloudKit
import Foundation
import Observation

/// iCloud backup and sync through the user's private CloudKit database: no
/// server of ours, and the data stays in their own iCloud.
///
/// The whole data set is one small JSON document, kept as one record. Each
/// sync fetches it, merges it with this device's data item by item
/// (`SnapshotMerge`), applies the result here, and uploads it if iCloud's
/// copy differs. Uploads only land if nobody else saved in between; if they
/// did, it fetches and merges again.
///
/// Syncs a few seconds after the user changes something (bursts of edits
/// become one sync), once at launch to bring in other devices' changes,
/// when the iCloud account changes, and from "Sync now". Not on every
/// return to the app.
///
/// Off until the person agrees: the iCloud popup (`ICloudConsentPopup`)
/// explains what's stored and asks first, and `needsConsent` stays true
/// until they answer it once (Guideline 5.1.3(ii): health data goes to
/// iCloud only with their say-so).
@MainActor
@Observable
final class CloudSync {
    static let shared = CloudSync()

    enum Status: Equatable {
        case off
        case idle
        case syncing
        case synced(Date)
        case noAccount
        case failed(String)
    }

    private(set) var status: Status
    private(set) var lastSynced: Date?

    /// True until they've answered the iCloud popup (or flipped the switch).
    private(set) var needsConsent: Bool

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.consentKey)
            needsConsent = false
            guard isEnabled != oldValue else { return }
            if isEnabled {
                status = .idle
                requestSync()
            } else {
                pending?.cancel()
                status = .off
            }
        }
    }

    static let containerID = "iCloud.com.doseday.ios"
    private static let recordID = CKRecord.ID(recordName: "snapshot")
    private static let recordType = "Snapshot"
    /// Whether they agreed to iCloud backup; missing until they answer.
    private static let consentKey = "icloud.consent"
    /// The old opt-out switch: someone who turned sync off keeps it off.
    private static let legacyDisabledKey = "icloud.syncDisabled"
    private static let lastSyncedKey = "icloud.lastSynced"

    /// Created on first use (a static `let` is lazy), once syncing starts.
    private static let container = CKContainer(identifier: containerID)
    private var database: CKDatabase { Self.container.privateCloudDatabase }
    @ObservationIgnored private weak var store: MedicineStore?
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var needsAnotherRun = false
    /// True while a merge from iCloud is being written into the store, so
    /// that save doesn't schedule yet another sync.
    @ObservationIgnored private var isApplying = false
    @ObservationIgnored private var accountObserver: NSObjectProtocol?

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.consentKey) == nil, defaults.bool(forKey: Self.legacyDisabledKey) {
            defaults.set(false, forKey: Self.consentKey)
        }
        let consent = defaults.object(forKey: Self.consentKey) as? Bool
        let enabled = consent ?? false
        needsConsent = consent == nil
        isEnabled = enabled
        status = enabled ? .idle : .off
        lastSynced = UserDefaults.standard.object(forKey: Self.lastSyncedKey) as? Date
    }

    // MARK: Triggers

    /// Starts syncing `store`, after launch. Skipped in previews.
    func start(store: MedicineStore) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        self.store = store
        if accountObserver == nil {
            accountObserver = NotificationCenter.default.addObserver(
                forName: .CKAccountChanged, object: nil, queue: .main
            ) { _ in
                Task { @MainActor in CloudSync.shared.requestSync() }
            }
        }
        requestSync()
    }

    /// The store saved a change; sync it shortly, batching bursts of edits.
    func localDidChange() {
        guard !isApplying else { return }
        requestSync(after: .seconds(4))
    }

    /// Syncs soon (or after `delay`), replacing any sync already waiting.
    func requestSync(after delay: Duration = .zero) {
        guard isEnabled, store != nil else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            await self?.syncNow()
        }
    }

    /// Syncs now; if a sync is already running, runs once more after it.
    func syncNow() async {
        guard isEnabled, let store else { return }
        if isRunning {
            needsAnotherRun = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        repeat {
            needsAnotherRun = false
            await performSync(store)
        } while needsAnotherRun && isEnabled
    }

    // MARK: Sync

    private func performSync(_ store: MedicineStore) async {
        status = .syncing
        do {
            guard try await Self.container.accountStatus() == .available else {
                status = .noAccount
                return
            }
            // A save from another device between fetch and upload makes the
            // upload fail; fetch, merge and try again.
            for _ in 0..<3 {
                let existing = try await fetchRecord()
                let remote = try existing.map(Self.decode)
                // No suspension from here to `apply`, so no edit is lost.
                let local = store.snapshot
                let merged = remote.map { SnapshotMerge.merge(base: Self.loadBase(), local: local, remote: $0) } ?? local
                if merged != local {
                    isApplying = true
                    store.apply(merged)
                    isApplying = false
                }
                if merged != remote {
                    do {
                        try await upload(merged, onto: existing)
                    } catch let error as CKError where error.code == .serverRecordChanged {
                        continue
                    }
                }
                Self.saveBase(merged)
                let now = Date.now
                lastSynced = now
                UserDefaults.standard.set(now, forKey: Self.lastSyncedKey)
                status = .synced(now)
                return
            }
            status = .failed(String(localized: "iCloud is busy. Try again in a moment."))
        } catch {
            status = Self.status(for: error)
        }
    }

    private func fetchRecord() async throws -> CKRecord? {
        do {
            return try await database.record(for: Self.recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func upload(_ snapshot: MedicineSnapshot, onto existing: CKRecord?) async throws {
        let record = existing ?? CKRecord(recordType: Self.recordType, recordID: Self.recordID)
        let file = FileManager.default.temporaryDirectory.appending(path: "doseday-sync-\(UUID().uuidString).json")
        try JSONEncoder().encode(snapshot).write(to: file, options: .atomic)
        defer { try? FileManager.default.removeItem(at: file) }
        record["data"] = CKAsset(fileURL: file)
        record["modifiedAt"] = Date.now as NSDate

        let (results, _) = try await database.modifyRecords(
            saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true
        )
        if case .failure(let error)? = results[record.recordID] { throw error }
    }

    private static func decode(_ record: CKRecord) throws -> MedicineSnapshot {
        guard let url = (record["data"] as? CKAsset)?.fileURL else { return MedicineSnapshot() }
        return try JSONDecoder().decode(MedicineSnapshot.self, from: Data(contentsOf: url))
    }

    private static func status(for error: Error) -> Status {
        guard let error = error as? CKError else { return .failed(error.localizedDescription) }
        switch error.code {
        case .notAuthenticated: return .noAccount
        case .networkUnavailable, .networkFailure: return .failed(String(localized: "You’re offline. It’ll sync when you’re back online."))
        case .quotaExceeded: return .failed(String(localized: "Your iCloud storage is full."))
        default: return .failed(error.localizedDescription)
        }
    }

    // MARK: Base

    /// The copy both sides agreed on at the last sync, kept beside the data.
    private static var baseURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "icloud-base.json")
    }

    private static func loadBase() -> MedicineSnapshot? {
        guard let data = try? Data(contentsOf: baseURL) else { return nil }
        return try? JSONDecoder().decode(MedicineSnapshot.self, from: data)
    }

    private static func saveBase(_ snapshot: MedicineSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: baseURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: Copy

    /// Short state for the Settings row.
    var summary: String {
        switch status {
        case .off: String(localized: "Off")
        case .noAccount: String(localized: "No iCloud")
        case .failed: String(localized: "Not synced")
        case .syncing: String(localized: "Syncing…")
        case .idle, .synced: String(localized: "On")
        }
    }

    /// One line for the iCloud page.
    var detail: String {
        switch status {
        case .off: String(localized: "Off")
        case .idle: lastSynced.map { String(localized: "Synced \($0.formatted(.relative(presentation: .named)))") } ?? String(localized: "Waiting to sync")
        case .syncing: String(localized: "Syncing…")
        case .synced(let date): String(localized: "Synced \(date.formatted(.relative(presentation: .named)))")
        case .noAccount: String(localized: "Sign in to iCloud in the Settings app")
        case .failed(let message): message
        }
    }
}
