import Foundation

/// Everything the app persists, saved as one JSON document. The data set is
/// small (a handful of medicines and a few hundred logs) so a single file
/// keeps saves atomic and the format easy to migrate.
struct MedicineSnapshot: Codable {
    var medicines: [Medicine] = []
    var doseLogs: [DoseLog] = []
    var refills: [RefillEvent] = []
    var settings = AppSettings()
    /// The last day whose untaken doses were counted down.
    var lastCountdownDay: Date?
    var contacts: [HealthContact] = []
    var checkIns: [DailyCheckIn] = []

    init(
        medicines: [Medicine] = [],
        doseLogs: [DoseLog] = [],
        refills: [RefillEvent] = [],
        settings: AppSettings = AppSettings(),
        lastCountdownDay: Date? = nil,
        contacts: [HealthContact] = [],
        checkIns: [DailyCheckIn] = []
    ) {
        self.medicines = medicines
        self.doseLogs = doseLogs
        self.refills = refills
        self.settings = settings
        self.lastCountdownDay = lastCountdownDay
        self.contacts = contacts
        self.checkIns = checkIns
    }

    private enum CodingKeys: String, CodingKey {
        case medicines, doseLogs, refills, settings, lastCountdownDay, contacts, checkIns
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
    }
}

protocol MedicineRepository {
    func load() -> MedicineSnapshot
    func save(_ snapshot: MedicineSnapshot)
}

/// Stores the snapshot in Application Support.
struct FileMedicineRepository: MedicineRepository {
    private let url: URL

    init(fileName: String = "medicines.json") {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appending(path: fileName)
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
            try data.write(to: url, options: [.atomic, .completeFileProtection])
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
