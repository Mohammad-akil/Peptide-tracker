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
/// Syncs at launch, on returning to the app, a few seconds after each
/// change, and when the iCloud account changes.
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

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(!isEnabled, forKey: Self.disabledKey)
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
    private static let disabledKey = "icloud.syncDisabled"
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
        let enabled = !UserDefaults.standard.bool(forKey: Self.disabledKey)
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
            status = .failed("iCloud is busy. Try again in a moment.")
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
        case .networkUnavailable, .networkFailure: return .failed("You’re offline. It’ll sync when you’re back online.")
        case .quotaExceeded: return .failed("Your iCloud storage is full.")
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
        case .off: "Off"
        case .noAccount: "No iCloud"
        case .failed: "Not synced"
        case .syncing: "Syncing…"
        case .idle, .synced: "On"
        }
    }

    /// One line for the iCloud page.
    var detail: String {
        switch status {
        case .off: "Off"
        case .idle: lastSynced.map { "Synced \($0.formatted(.relative(presentation: .named)))" } ?? "Waiting to sync"
        case .syncing: "Syncing…"
        case .synced(let date): "Synced \(date.formatted(.relative(presentation: .named)))"
        case .noAccount: "Sign in to iCloud in the Settings app"
        case .failed(let message): message
        }
    }
}
