import UIKit
import UserNotifications

/// Owns the app-wide store and router so notification callbacks — which
/// arrive here, outside SwiftUI — can act on the same instances the views
/// read.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let store = MedicineStore()
    let router = AppRouter()
    let purchases = PurchaseStore()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        store.scheduler.registerCategories(snooze: store.settings.snooze)
        #if DEBUG
        // Launch with `-sampleData` to start from the design's cabinet.
        if ProcessInfo.processInfo.arguments.contains("-sampleData") { store.loadSampleData() }
        // `-tab medicines` opens straight onto a tab, for screenshots.
        if let tab = UserDefaults.standard.string(forKey: "tab"),
           let match = AppRouter.Tab.allCases.first(where: { $0.title.lowercased() == tab }) {
            router.selectedTab = match
        }
        #endif
        store.runDailyCountdown()
        store.rescheduleReminders()
        return true
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
        let idString = response.notification.request.content.userInfo[ReminderScheduler.medicineIDKey] as? String
        guard let idString, let id = UUID(uuidString: idString) else { return }
        await handle(action: action, medicineID: id)
    }

    private func handle(action: String, medicineID: UUID) async {
        guard let medicine = store.medicine(id: medicineID) else { return }
        switch action {
        case ReminderScheduler.Action.markRefilled:
            store.refill(medicineID, adding: store.suggestedRefillAmount(for: medicine))
            // This can run with the app in the background, where the store's
            // debounced re-plan may never get to fire — move the reminder now.
            await store.scheduler.clear(medicine)
            await store.scheduler.reschedule(medicines: store.medicines, settings: store.settings)
        case ReminderScheduler.Action.markOrdered:
            // Reminders pause until the refill is picked up.
            store.markOrdered(medicineID)
            await store.scheduler.clear(medicine)
            await store.scheduler.reschedule(medicines: store.medicines, settings: store.settings)
        case ReminderScheduler.Action.remindTomorrow:
            await store.scheduler.snooze(medicine, settings: store.settings)
        default:
            // Tapping the reminder itself.
            router.openMedicine(medicineID)
        }
    }
}
