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
