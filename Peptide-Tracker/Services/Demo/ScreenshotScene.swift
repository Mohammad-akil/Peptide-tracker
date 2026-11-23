#if DEBUG
import SwiftUI

/// The App Store screenshots, one per major screen, in listing order.
/// Debug builds only. Each scene loads the demo cabinet and opens its
/// screen; the Screenshot Studio (Settings → Developer) captures them.
enum ScreenshotScene: String, CaseIterable, Identifiable {
    case today, pillbox, medicines, medicine, calendar, reminders
    case mood, sideEffects, report, health, privacy, travel, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .pillbox: "Today · pillbox"
        case .medicines: "Medicines"
        case .medicine: "Medicine detail (injection)"
        case .calendar: "Calendar"
        case .reminders: "All reminders"
        case .mood: "Mood check-in"
        case .sideEffects: "Side effects"
        case .report: "Report"
        case .health: "Health"
        case .privacy: "Privacy"
        case .travel: "Travel"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: "checklist"
        case .pillbox: "square.grid.2x2.fill"
        case .medicines: "pills.fill"
        case .medicine: "syringe.fill"
        case .calendar: "calendar"
        case .reminders: "bell.fill"
        case .mood: "face.smiling.inverse"
        case .sideEffects: "list.bullet.clipboard.fill"
        case .report: "chart.bar.fill"
        case .health: "heart.fill"
        case .privacy: "hand.raised.fill"
        case .travel: "airplane"
        case .settings: "gearshape.fill"
        }
    }

    /// What the shot shows, for the studio list.
    var hint: String {
        switch self {
        case .today: "Today’s doses with one left to take"
        case .pillbox: "The square pillbox layout"
        case .medicines: "The cabinet, soonest to run out first"
        case .medicine: "Supply ring, injection sites and pen life"
        case .calendar: "A year of doses at a glance"
        case .reminders: "Every refill reminder, grouped"
        case .mood: "The daily mood check-in"
        case .sideEffects: "Side effects with patterns"
        case .report: "Adherence report for the doctor"
        case .health: "Mood, weight, calculators, sharps"
        case .privacy: "App Lock and hidden names"
        case .travel: "Home time and trip planner"
        case .settings: "Settings home"
        }
    }

    /// Loads the demo cabinet (once per launch) and opens this screen.
    @MainActor
    func open(router: AppRouter, store: MedicineStore) {
        if !Self.didLoadSample {
            store.loadSampleData()
            Self.didLoadSample = true
        }
        let defaults = UserDefaults.standard
        defaults.set(self == .pillbox ? DoseLayout.squarePillbox.rawValue : DoseLayout.list.rawValue, forKey: DoseLayout.storageKey)
        // The free 7-day report, so nothing is blurred behind the Pro lock.
        defaults.set(AdherenceReport.Period.week.rawValue, forKey: "report.period")

        router.sheet = nil
        router.path = []
        switch self {
        case .today, .pillbox:
            router.showToday(nil)
        case .medicines:
            router.selectedTab = .medicines
        case .medicine:
            if let id = store.medicines.first(where: { $0.type == .injection })?.id ?? store.medicines.first?.id {
                router.openMedicine(id)
            }
        case .calendar:
            router.showToday(.calendar)
        case .reminders:
            router.selectedTab = .today
            router.push(.reminders)
        case .mood:
            router.showToday(.mood)
        case .sideEffects:
            router.selectedTab = .settings
            router.push(.settings(.health))
            router.sheet = .sideEffects
        case .report:
            router.selectedTab = .settings
            router.push(.settings(.report))
        case .health:
            router.selectedTab = .settings
            router.push(.settings(.health))
        case .privacy:
            router.selectedTab = .settings
            router.push(.settings(.privacy))
        case .travel:
            router.selectedTab = .settings
            router.push(.settings(.travel))
        case .settings:
            router.selectedTab = .settings
        }
    }

    private static var didLoadSample = false
}
#endif
