import Foundation

/// Everything the app persists, saved as one JSON document. The data set is
/// small (a handful of medicines and a few hundred logs) so a single file
/// keeps saves atomic and the format easy to migrate.
struct MedicineSnapshot: Codable, Equatable {
    var medicines: [Medicine] = []
    var doseLogs: [DoseLog] = []
    var refills: [RefillEvent] = []
    var settings = AppSettings()
    /// The last day whose untaken doses were counted down.
    var lastCountdownDay: Date?
    var contacts: [HealthContact] = []
    var checkIns: [DailyCheckIn] = []
    var weights: [WeightEntry] = []
    var calculatorResults: [CalculatorResult] = []
    var sideEffects: [SideEffectEntry] = []

    init(
        medicines: [Medicine] = [],
        doseLogs: [DoseLog] = [],
        refills: [RefillEvent] = [],
        settings: AppSettings = AppSettings(),
        lastCountdownDay: Date? = nil,
        contacts: [HealthContact] = [],
        checkIns: [DailyCheckIn] = [],
        weights: [WeightEntry] = [],
        calculatorResults: [CalculatorResult] = [],
        sideEffects: [SideEffectEntry] = []
    ) {
        self.medicines = medicines
        self.doseLogs = doseLogs
        self.refills = refills
        self.settings = settings
        self.lastCountdownDay = lastCountdownDay
        self.contacts = contacts
        self.checkIns = checkIns
        self.weights = weights
        self.calculatorResults = calculatorResults
        self.sideEffects = sideEffects
    }

    private enum CodingKeys: String, CodingKey {
        case medicines, doseLogs, refills, settings, lastCountdownDay, contacts, checkIns, weights, calculatorResults, sideEffects
    }

    /// Tolerates keys added in later versions (`contacts`, `checkIns`), so an older
    /// save still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        medicines = try c.decodeIfPresent([Medicine].self, forKey: .medicines) ?? []
        doseLogs = try c.decodeIfPresent([DoseLog].self, forKey: .doseLogs) ?? []
        refills = try c.decodeIfPresent([RefillEvent].self, forKey: .refills) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        lastCountdownDay = try c.decodeIfPresent(Date.self, forKey: .lastCountdownDay)
        contacts = try c.decodeIfPresent([HealthContact].self, forKey: .contacts) ?? []
        checkIns = try c.decodeIfPresent([DailyCheckIn].self, forKey: .checkIns) ?? []
        weights = try c.decodeIfPresent([WeightEntry].self, forKey: .weights) ?? []
        calculatorResults = try c.decodeIfPresent([CalculatorResult].self, forKey: .calculatorResults) ?? []
        sideEffects = try c.decodeIfPresent([SideEffectEntry].self, forKey: .sideEffects) ?? []
    }
}

protocol MedicineRepository {
    func load() -> MedicineSnapshot
    func save(_ snapshot: MedicineSnapshot)
}

/// The App Group the app and its widgets share. Must match the App Groups
/// capability on both targets.
enum AppGroup {
    static let id = "group.com.doseday.ios.shared"

    /// The shared folder, or nil until the App Groups capability is added.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }
}

/// Stores the snapshot in the App Group's shared folder (so the widgets can
/// read it and log doses), falling back to Application Support when the
/// group isn't set up. A file saved by an older build is moved across once.
struct FileMedicineRepository: MedicineRepository {
    private let url: URL

    init(fileName: String = "medicines.json") {
        let local = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        let legacy = local.appending(path: fileName)
        guard let shared = AppGroup.containerURL else {
            url = legacy
            return
        }
        url = shared.appending(path: fileName)
        if !FileManager.default.fileExists(atPath: url.path()), FileManager.default.fileExists(atPath: legacy.path()) {
            try? FileManager.default.copyItem(at: legacy, to: url)
        }
    }

    func load() -> MedicineSnapshot {
        guard let data = try? Data(contentsOf: url) else { return MedicineSnapshot() }
        do {
            return try JSONDecoder().decode(MedicineSnapshot.self, from: data)
        } catch {
            assertionFailure("Couldn't decode saved medicines: \(error)")
            return MedicineSnapshot()
        }
    }

    func save(_ snapshot: MedicineSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            // Readable after first unlock, so lock-screen widgets still work.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            assertionFailure("Couldn't save medicines: \(error)")
        }
    }
}

/// Keeps everything in memory — for previews.
final class InMemoryMedicineRepository: MedicineRepository {
    private var snapshot: MedicineSnapshot

    init(_ snapshot: MedicineSnapshot = MedicineSnapshot()) {
        self.snapshot = snapshot
    }

    func load() -> MedicineSnapshot { snapshot }
    func save(_ snapshot: MedicineSnapshot) { self.snapshot = snapshot }
}
