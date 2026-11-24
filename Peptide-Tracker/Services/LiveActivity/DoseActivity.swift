import ActivityKit
import AppIntents
import Foundation

/// The Lock Screen and Dynamic Island card for the next dose. Must match
/// `DosedayWidgets/DoseLiveActivity.swift` field for field — the widget
/// extension draws it, the app starts and updates it.
nonisolated struct DoseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Nil once every dose today is taken.
        var medicineID: String?
        var minutes: Int
        var title: String
        var detail: String
        var dueAt: Date
        var symbol: String
        var taken: Int
        var total: Int
    }
}

/// Starts, updates and ends the next-dose Live Activity. The store calls
/// `refresh` after every change, so ticking a dose anywhere moves it on.
@MainActor
enum DoseActivityController {
    static var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    static var isRunning: Bool { !Activity<DoseActivityAttributes>.activities.isEmpty }

    /// "Pin to Lock Screen" on Today.
    static func start(store: MedicineStore) {
        guard isAvailable, let state = makeState(store: store) else { return }
        if isRunning {
            refresh(store: store)
            return
        }
        _ = try? Activity.request(
            attributes: DoseActivityAttributes(),
            content: ActivityContent(state: state, staleDate: state.dueAt.addingTimeInterval(3 * 3600)),
            pushType: nil
        )
    }

    /// Moves the card on to the next dose, or ends it once the day is done.
    static func refresh(store: MedicineStore) {
        guard isRunning else { return }
        let activities = Activity<DoseActivityAttributes>.activities
        Task {
            guard let state = makeState(store: store), state.medicineID != nil else {
                let final = makeState(store: store)
                for activity in activities {
                    await activity.end(final.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: .after(.now.addingTimeInterval(15 * 60)))
                }
                return
            }
            for activity in activities {
                await activity.update(ActivityContent(state: state, staleDate: state.dueAt.addingTimeInterval(3 * 3600)))
            }
        }
    }

    static func end() {
        let activities = Activity<DoseActivityAttributes>.activities
        Task {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Today's next untaken dose, or an "all done" state; nil with no doses
    /// today at all.
    static func makeState(store: MedicineStore, now: Date = .now) -> DoseActivityAttributes.ContentState? {
        let doses = store.doses(on: now)
        guard !doses.isEmpty else { return nil }
        let taken = doses.filter(\.isTaken).count
        guard let next = store.nextDueDose(now: now) else {
            return .init(medicineID: nil, minutes: 0, title: String(localized: "All done today"), detail: String(localized: "\(taken) of \(doses.count) doses taken"), dueAt: now, symbol: "checkmark.circle.fill", taken: taken, total: doses.count)
        }
        let medicine = next.medicine
        var detail = medicine.unit.format(medicine.unitsPerIntake)
        if medicine.type == .injection, store.settings.tracksDoses {
            detail += " · \(store.suggestedSite().title)"
        }
        return .init(
            medicineID: medicine.id.uuidString,
            minutes: next.time.minutesSinceMidnight,
            title: store.settings.notificationName(for: medicine),
            detail: detail,
            dueAt: next.scheduledAt,
            symbol: medicine.type.symbol,
            taken: taken,
            total: doses.count
        )
    }
}

extension MedicineStore {
    /// Today's first dose not yet taken, overdue ones first.
    func nextDueDose(now: Date = .now) -> ScheduledDose? {
        doses(on: now).first { !$0.isTaken }
    }
}

// MARK: - Buttons and Siri

/// "Taken" on the Live Activity. Declared in the widget extension too (so
/// the button can name it); as a Live Activity intent it always runs here,
/// in the app, against the shared store.
struct CompleteDoseActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark dose taken"
    static let isDiscoverable = false

    @Parameter(title: "Medicine") var medicineID: String
    @Parameter(title: "Minutes after midnight") var minutes: Int

    init() {}

    init(medicineID: String, minutes: Int) {
        self.medicineID = medicineID
        self.minutes = minutes
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = MedicineStore.shared
        store.reloadFromDisk()
        if let id = UUID(uuidString: medicineID) {
            store.markTaken(medicineID: id, day: .now.startOfDay, minutes: minutes)
        }
        DoseActivityController.refresh(store: store)
        return .result()
    }
}

/// "Log my dose in Doseday": ticks off the next dose due today.
struct LogNextDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log next dose"
    static let description = IntentDescription("Ticks off your next dose due today.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = MedicineStore.shared
        store.reloadFromDisk()
        guard let dose = store.nextDueDose() else {
            return .result(dialog: "Nothing left to take today. You’re all caught up.")
        }
        store.toggle(dose)
        let name = store.settings.notificationName(for: dose.medicine)
        if let next = store.nextDueDose() {
            return .result(dialog: "Logged \(name) for \(dose.time.label). Next: \(store.settings.notificationName(for: next.medicine)) at \(next.time.label).")
        }
        return .result(dialog: "Logged \(name) for \(dose.time.label). That’s everything for today.")
    }
}

/// "What's left in Doseday": today's untaken doses, read out.
struct DosesLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "Doses left today"
    static let description = IntentDescription("Tells you which doses you still have to take today.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = MedicineStore.shared
        store.reloadFromDisk()
        let left = store.doses(on: .now).filter { !$0.isTaken }
        guard !left.isEmpty else { return .result(dialog: "Nothing left today. You’re all caught up.") }
        let list = left.prefix(4).map { String(localized: "\(store.settings.notificationName(for: $0.medicine)) at \($0.time.label)") }
        let more = left.count > 4 ? String(localized: ", and \(left.count - 4) more") : ""
        return .result(dialog: "\(left.count) left: \(list.joined(separator: ", "))\(more).")
    }
}

struct DosedayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogNextDoseIntent(),
            phrases: [
                "Log my dose in \(.applicationName)",
                "Log next dose in \(.applicationName)",
                "I took my dose in \(.applicationName)",
            ],
            shortTitle: "Log next dose",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: DosesLeftIntent(),
            phrases: [
                "What doses are left in \(.applicationName)",
                "What's left to take in \(.applicationName)",
            ],
            shortTitle: "Doses left today",
            systemImageName: "list.bullet"
        )
    }
}
