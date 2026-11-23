import UIKit
import UserNotifications

/// Owns the app-wide store and router so notification callbacks — which
/// arrive here, outside SwiftUI — can act on the same instances the views
/// read.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let store = MedicineStore.shared
    let router = AppRouter()
    let purchases = PurchaseStore()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Back chevrons and bar buttons: black in light mode, white in dark,
        // like the toolbar icons — the accent stays for primary actions.
        UINavigationBar.appearance().tintColor = UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? 0xF4F3F8 : 0x111418)
        }
        #if DEBUG
        // Launch with `-sampleData` to start from the design's cabinet.
        if ProcessInfo.processInfo.arguments.contains("-sampleData") { store.loadSampleData() }
        // `-tab medicines` opens straight onto a tab, for screenshots.
        if let tab = UserDefaults.standard.string(forKey: "tab"),
           let match = AppRouter.Tab.allCases.first(where: { $0.title.lowercased() == tab }) {
            router.selectedTab = match
        }
        // `-open doseday://calendar` follows a link at launch, for screenshots.
        if let link = UserDefaults.standard.string(forKey: "open"), let url = URL(string: link) {
            router.handle(url, medicineCount: store.medicines.count, purchases: purchases)
        }
        #endif
        // Privacy mode: locked until Face ID or the passcode. Before the
        // first frame, so nothing private ever shows.
        AppLock.shared.launch(enabled: store.settings.appLock)
        // Everything else waits for the splash to be on screen
        // (`finishLaunching`), so launch draws its first frame at once.
        return true
    }

    /// Launch work that can wait a frame: called once the splash is up.
    func finishLaunching() {
        purchases.start()
        store.scheduler.registerCategories(snooze: store.settings.snooze)
        store.runDailyCountdown()
        store.rescheduleReminders()
    }

    // Show reminders even while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let request = response.notification.request
        let info = request.content.userInfo
        let idString = info[ReminderScheduler.medicineIDKey] as? String
        guard let idString, let id = UUID(uuidString: idString) else { return }
        // Dose reminders carry their day and time.
        if request.content.categoryIdentifier == ReminderScheduler.Category.dose,
           let day = info[ReminderScheduler.DoseKey.day] as? Double,
           let minutes = info[ReminderScheduler.DoseKey.minutes] as? Int {
            await handleDose(action: action, medicineID: id, day: Date(timeIntervalSince1970: day), minutes: minutes, request: request)
            return
        }
        await handle(action: action, medicineID: id)
    }

    /// "Taken" ticks the dose without opening the app; "in 10 minutes"
    /// re-sends it; tapping the reminder opens Today on that day.
    private func handleDose(action: String, medicineID: UUID, day: Date, minutes: Int, request: UNNotificationRequest) async {
        switch action {
        case ReminderScheduler.Action.markTaken:
            store.reloadFromDisk()
            store.markTaken(medicineID: medicineID, day: day, minutes: minutes)
        case ReminderScheduler.Action.snoozeDose:
            await store.scheduler.snoozeDose(request)
        default:
            router.showToday(.day(day))
        }
    }

    private func handle(action: String, medicineID: UUID) async {
        guard let medicine = store.medicine(id: medicineID) else { return }
        switch action {
        case ReminderScheduler.Action.markRefilled:
            store.refill(medicineID, adding: store.suggestedRefillAmount(for: medicine))
            // This can run with the app in the background, where the store's
            // debounced re-plan may never get to fire — move the reminder now.
            await store.scheduler.clear(medicine)
            await store.scheduler.reschedule(medicines: store.medicines, settings: store.settings, takenDoseIDs: store.takenDoseIDs, siteLastUsed: store.lastUsed())
        case ReminderScheduler.Action.markOrdered:
            // Reminders pause until the refill is picked up.
            store.markOrdered(medicineID)
            await store.scheduler.clear(medicine)
            await store.scheduler.reschedule(medicines: store.medicines, settings: store.settings, takenDoseIDs: store.takenDoseIDs, siteLastUsed: store.lastUsed())
        case ReminderScheduler.Action.remindTomorrow:
            await store.scheduler.snooze(medicine, settings: store.settings)
        default:
            // Tapping the reminder itself.
            router.openMedicine(medicineID)
        }
    }
}
