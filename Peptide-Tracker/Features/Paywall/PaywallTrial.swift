import SwiftUI
import UserNotifications

/// Keeps the paywall's trial promise: a local notification two days before a
/// free trial turns into a paid subscription.
enum TrialReminder {
    static let identifier = "pro.trial.reminder"
    static let daysBeforeEnd = 2

    /// Call after a purchase that started a free trial.
    static func schedule(trialDays: Int, price: String, period: String) async {
        guard trialDays > daysBeforeEnd else { return }
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends in \(daysBeforeEnd) days"
        content.body = "Then it’s \(price) \(period). Cancel anytime in Settings before then if Pro isn’t for you."
        content.sound = .default
        let seconds = Double(trialDays - daysBeforeEnd) * 86_400
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
