import Foundation
import UserNotifications

/// Owns every local notification the app sends: one heads-up per medicine a
/// few days before it runs out, repeated each morning until it's ordered or
/// refilled if the user wants that, plus the optional morning and bedtime
/// nudges to check the day's doses.
/// `reschedule` is idempotent — the store calls it after every change and
/// it rebuilds the pending set from scratch.
final class ReminderScheduler {
    enum Category {
        static let refill = "REFILL_REMINDER"
        static let dose = "DOSE_REMINDER"
    }

    /// Keys a dose reminder carries, so "Taken" can tick that exact dose.
    enum DoseKey {
        static let day = "doseDay"
        static let minutes = "doseMinutes"
    }

    enum Action {
        static let markRefilled = "MARK_REFILLED"
        static let markOrdered = "MARK_ORDERED"
        static let remindTomorrow = "REMIND_TOMORROW"
        static let markTaken = "MARK_TAKEN"
        static let snoozeDose = "SNOOZE_DOSE"
    }

    /// How many extra mornings "Remind again until refilled" covers. The
    /// plan is rebuilt on every launch and change, so this only needs to
    /// outlast a stretch of not opening the app.
    private static let repeatDays = 14

    nonisolated static let medicineIDKey = "medicineID"

    private enum Prefix {
        static let refill = "refill."
        static let snooze = "snooze."
        static let daily = "daily."
    }

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// The snooze button's title follows the snooze setting, so this runs
    /// again whenever reminders are re-planned.
    func registerCategories(snooze: SnoozeOption = .tomorrow) {
        let refill = UNNotificationCategory(
            identifier: Category.refill,
            actions: [
                UNNotificationAction(identifier: Action.markRefilled, title: "Refilled",
                                     icon: UNNotificationActionIcon(systemImageName: "arrow.up")),
                UNNotificationAction(identifier: Action.markOrdered, title: "Ordered, check in later",
                                     icon: UNNotificationActionIcon(systemImageName: "shippingbox")),
                UNNotificationAction(identifier: Action.remindTomorrow, title: snooze.actionTitle,
                                     icon: UNNotificationActionIcon(systemImageName: "clock")),
            ],
            intentIdentifiers: []
        )
        let dose = UNNotificationCategory(
            identifier: Category.dose,
            actions: [
                UNNotificationAction(identifier: Action.markTaken, title: "Taken",
                                     icon: UNNotificationActionIcon(systemImageName: "checkmark")),
                UNNotificationAction(identifier: Action.snoozeDose, title: "Remind me in 10 minutes",
                                     icon: UNNotificationActionIcon(systemImageName: "clock")),
            ],
            intentIdentifiers: []
        )
        center.setNotificationCategories([refill, dose])
    }

    // MARK: Permission

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Shows the system prompt. Returns whether notifications are allowed.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Scheduling

    /// `takenDoseIDs` (`ScheduledDose.id`s) are already ticked off, so they
    /// get no dose-time reminder.
    func reschedule(medicines: [Medicine], settings: AppSettings, takenDoseIDs: Set<String> = [], now: Date = .now) async {
        registerCategories(snooze: settings.snooze)
        let pending = await center.pendingNotificationRequests()
        // Older builds also scheduled daily dose check-ins under "dose.".
        let stale = pending.map(\.identifier).filter {
            $0.hasPrefix(Prefix.refill) || $0.hasPrefix(Prefix.daily) || $0.hasPrefix("dose.")
        }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard settings.notificationsEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))
            return
        }

        for medicine in medicines where medicine.wantsReminder {
            let first = medicine.reminderDate(now: now)
            let repeats = settings.remindAgainUntilRefilled ? Self.repeatDays : 0
            for day in 0...repeats {
                let fireDate = first.adding(days: day)
                guard fireDate > now else { continue }
                let id = Prefix.refill + medicine.id.uuidString + (day == 0 ? "" : ".\(day)")
                try? await center.add(refillRequest(for: medicine, settings: settings, at: fireDate, id: id))
            }
        }

        if settings.doseReminders {
            for request in doseRequests(medicines: medicines, settings: settings, takenDoseIDs: takenDoseIDs, now: now) {
                try? await center.add(request)
            }
        }

        if settings.morningReminder, !medicines.isEmpty {
            try? await center.add(dailyRequest(
                id: Prefix.daily + "morning",
                title: "Good morning",
                body: "Check today’s doses in \(Bundle.main.appName).",
                at: settings.morningTime
            ))
        }
        if settings.sleepReminder, !medicines.isEmpty {
            try? await center.add(dailyRequest(
                id: Prefix.daily + "sleep",
                title: "Before bed",
                body: "Any doses left for today? Tick them off so your count stays right.",
                at: settings.sleepTime
            ))
        }
    }

    /// Clears a medicine's queued and delivered reminders — after it's
    /// marked ordered or refilled from a notification.
    func clear(_ medicine: Medicine) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let ids = pending.filter { $0.contains(medicine.id.uuidString) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let delivered = await center.deliveredNotifications()
            .filter { $0.request.content.threadIdentifier == medicine.id.uuidString }
            .map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }

    /// "Remind me in 10 minutes" on a dose reminder: the same reminder again.
    func snoozeDose(_ request: UNNotificationRequest) async {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: request.identifier + ".snooze", content: content, trigger: trigger))
    }

    /// The "Remind me later" action, after the snooze setting's wait.
    func snooze(_ medicine: Medicine, settings: AppSettings = AppSettings(), now: Date = .now) async {
        let date = settings.snooze.date(from: now, reminderTime: medicine.reminderTime)
        try? await center.add(refillRequest(for: medicine, settings: settings, at: date, id: Prefix.snooze + medicine.id.uuidString))
    }

    /// "Metformin runs out in 3 days" / "Tap to refill.", in the user's
    /// wording and with the name hidden if they asked.
    static func refillTitle(for medicine: Medicine, settings: AppSettings, at date: Date) -> String {
        let name = settings.notificationName(for: medicine)
        let days = Calendar.current.days(from: date, to: medicine.runOutDate())
        return days > 0 ? "\(name) runs out in \(days) \(days == 1 ? "day" : "days")" : "\(name) has run out"
    }

    private func refillRequest(for medicine: Medicine, settings: AppSettings, at date: Date, id: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = Self.refillTitle(for: medicine, settings: settings, at: date)
        content.body = settings.notificationMessage(for: medicine)
        content.sound = .default
        content.categoryIdentifier = Category.refill
        content.threadIdentifier = medicine.id.uuidString
        content.userInfo = [Self.medicineIDKey: medicine.id.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    // MARK: Dose times

    /// Days ahead dose reminders are planned for; re-planned on every change
    /// and launch, so the window keeps rolling forward.
    private static let doseDaysAhead = 7
    /// iOS keeps at most 64 pending notifications; leave room for refills.
    private static let maxDoseReminders = 40

    /// One notification per upcoming dose on each medicine's dose days,
    /// soonest first.
    private func doseRequests(medicines: [Medicine], settings: AppSettings, takenDoseIDs: Set<String>, now: Date) -> [UNNotificationRequest] {
        var doses: [(date: Date, medicine: Medicine, id: String)] = []
        for offset in 0..<Self.doseDaysAhead {
            let day = now.startOfDay.adding(days: offset)
            for medicine in medicines where medicine.createdAt.startOfDay <= day && medicine.isScheduled(on: day) {
                for time in medicine.intakeTimes {
                    let date = time.on(day)
                    guard date > now else { continue }
                    let doseID = "\(medicine.id)-\(day.timeIntervalSince1970)-\(time.minutesSinceMidnight)"
                    guard !takenDoseIDs.contains(doseID) else { continue }
                    doses.append((date, medicine, doseID))
                }
            }
        }
        return doses
            .sorted { $0.date < $1.date }
            .prefix(Self.maxDoseReminders)
            .map { dose in
                let content = UNMutableNotificationContent()
                content.title = "Time for \(settings.notificationName(for: dose.medicine))"
                let amount = dose.medicine.unit.format(dose.medicine.unitsPerIntake)
                content.body = "\(amount) · Tap to tick it off."
                content.sound = .default
                content.threadIdentifier = dose.medicine.id.uuidString
                content.categoryIdentifier = Category.dose
                content.userInfo = [
                    Self.medicineIDKey: dose.medicine.id.uuidString,
                    DoseKey.day: dose.date.startOfDay.timeIntervalSince1970,
                    DoseKey.minutes: Calendar.current.component(.hour, from: dose.date) * 60 + Calendar.current.component(.minute, from: dose.date),
                ]
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dose.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                return UNNotificationRequest(identifier: "dose." + dose.id, content: content, trigger: trigger)
            }
    }

    /// A nudge that repeats every day at `time`.
    private func dailyRequest(id: String, title: String, body: String, at time: TimeOfDay) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: time.hour, minute: time.minute), repeats: true)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}
