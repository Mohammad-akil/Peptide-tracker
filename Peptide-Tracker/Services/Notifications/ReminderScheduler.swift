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
        static let prep = "prep."
        static let discard = "discard."
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
                UNNotificationAction(identifier: Action.markRefilled, title: String(localized: "Refilled"),
                                     icon: UNNotificationActionIcon(systemImageName: "arrow.up")),
                UNNotificationAction(identifier: Action.markOrdered, title: String(localized: "Ordered, check in later"),
                                     icon: UNNotificationActionIcon(systemImageName: "shippingbox")),
                UNNotificationAction(identifier: Action.remindTomorrow, title: snooze.actionTitle,
                                     icon: UNNotificationActionIcon(systemImageName: "clock")),
            ],
            intentIdentifiers: []
        )
        let dose = UNNotificationCategory(
            identifier: Category.dose,
            actions: [
                UNNotificationAction(identifier: Action.markTaken, title: String(localized: "Taken"),
                                     icon: UNNotificationActionIcon(systemImageName: "checkmark")),
                UNNotificationAction(identifier: Action.snoozeDose, title: String(localized: "Remind me in 10 minutes"),
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
    /// get no dose-time reminder. `siteLastUsed` lets injection reminders
    /// name the site to use next.
    func reschedule(
        medicines: [Medicine],
        settings: AppSettings,
        takenDoseIDs: Set<String> = [],
        siteLastUsed: [InjectionSite: Date] = [:],
        now: Date = .now
    ) async {
        registerCategories(snooze: settings.snooze)
        let pending = await center.pendingNotificationRequests()
        // Older builds also scheduled daily dose check-ins under "dose.".
        let stale = pending.map(\.identifier).filter {
            $0.hasPrefix(Prefix.refill) || $0.hasPrefix(Prefix.daily) || $0.hasPrefix("dose.")
                || $0.hasPrefix(Prefix.prep) || $0.hasPrefix(Prefix.discard)
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

        for medicine in medicines {
            if let request = discardRequest(for: medicine, settings: settings, now: now) {
                try? await center.add(request)
            }
        }

        if settings.doseReminders {
            for request in doseRequests(medicines: medicines, settings: settings, takenDoseIDs: takenDoseIDs, siteLastUsed: siteLastUsed, now: now) {
                try? await center.add(request)
            }
        }

        if settings.morningReminder, !medicines.isEmpty {
            try? await center.add(dailyRequest(
                id: Prefix.daily + "morning",
                title: String(localized: "Good morning"),
                body: String(localized: "Check today’s doses in \(Bundle.main.appName)."),
                at: settings.morningTime
            ))
        }
        if settings.sleepReminder, !medicines.isEmpty {
            try? await center.add(dailyRequest(
                id: Prefix.daily + "sleep",
                title: String(localized: "Before bed"),
                body: String(localized: "Any doses left for today? Tick them off so your count stays right."),
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
        return days > 0 ? (days == 1 ? String(localized: "\(name) runs out in 1 day") : String(localized: "\(name) runs out in \(days) days")) : String(localized: "\(name) has run out")
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
    /// soonest first. Injections name the site to use, following the
    /// rotation forward from one injection to the next.
    private func doseRequests(
        medicines: [Medicine],
        settings: AppSettings,
        takenDoseIDs: Set<String>,
        siteLastUsed: [InjectionSite: Date],
        now: Date
    ) -> [UNNotificationRequest] {
        // Doses are planned on the dose clock: local time, or home time
        // while travelling with "Keep home time" on.
        var doseCalendar = Calendar.current
        doseCalendar.timeZone = settings.doseTimeZone
        let firstDay = doseCalendar.startOfDay(for: now)

        var doses: [(date: Date, day: Date, time: TimeOfDay, medicine: Medicine, id: String)] = []
        for offset in 0..<Self.doseDaysAhead {
            guard let dayInZone = doseCalendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }
            // The same calendar day as a local date, which is how the store
            // keys doses.
            let day = Self.localDay(matching: dayInZone, in: doseCalendar)
            for medicine in medicines where medicine.createdAt.startOfDay <= day && medicine.isScheduled(on: day) {
                for time in medicine.intakeTimes {
                    let date = time.on(dayInZone, calendar: doseCalendar)
                    guard date > now else { continue }
                    let doseID = "\(medicine.id)-\(day.timeIntervalSince1970)-\(time.minutesSinceMidnight)"
                    guard !takenDoseIDs.contains(doseID) else { continue }
                    doses.append((date, day, time, medicine, doseID))
                }
            }
        }
        let upcoming = doses
            .sorted { $0.date < $1.date }
            .prefix(Self.maxDoseReminders)
        let injectionCount = upcoming.filter { $0.medicine.type == .injection }.count
        var sites = InjectionSite.upcoming(injectionCount, lastUsed: siteLastUsed, skipping: settings.skippedSiteAreas)
            .makeIterator()

        var requests: [UNNotificationRequest] = upcoming.map { dose in
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Time for \(settings.notificationName(for: dose.medicine))")
            let amount = dose.medicine.unit.format(dose.medicine.unitsPerIntake)
            if dose.medicine.type == .injection, settings.tracksDoses, let site = sites.next() {
                content.body = String(localized: "\(amount) · Next site: \(site.title.lowercased()). Tap to log it.")
            } else {
                content.body = String(localized: "\(amount) · Tap to tick it off.")
            }
            content.sound = .default
            content.threadIdentifier = dose.medicine.id.uuidString
            content.categoryIdentifier = Category.dose
            content.userInfo = [
                Self.medicineIDKey: dose.medicine.id.uuidString,
                DoseKey.day: dose.day.timeIntervalSince1970,
                DoseKey.minutes: dose.time.minutesSinceMidnight,
            ]
            return UNNotificationRequest(identifier: "dose." + dose.id, content: content, trigger: Self.trigger(at: dose.date, in: doseCalendar))
        }

        // "Take it out of the fridge" ahead of injections that want it.
        let prepped = upcoming.filter { $0.medicine.hasPrepReminder }.prefix(Self.maxPrepReminders)
        for dose in prepped {
            let minutes = dose.medicine.prepMinutes ?? 0
            let fireDate = dose.date.addingTimeInterval(-Double(minutes) * 60)
            guard fireDate > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Out of the fridge")
            content.body = String(localized: "Take \(settings.notificationName(for: dose.medicine)) out now. Dose at \(dose.time.label).")
            content.sound = .default
            content.threadIdentifier = dose.medicine.id.uuidString
            content.userInfo = [Self.medicineIDKey: dose.medicine.id.uuidString]
            requests.append(UNNotificationRequest(identifier: Prefix.prep + dose.id, content: content, trigger: Self.trigger(at: fireDate, in: doseCalendar)))
        }
        return requests
    }

    /// Fridge nudges planned at most; they share iOS's 64-notification cap.
    private static let maxPrepReminders = 8

    /// The local start of the day with the same year, month and day as
    /// `date` has in `calendar`.
    private static func localDay(matching date: Date, in calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return Calendar.current.date(from: parts)?.startOfDay ?? date.startOfDay
    }

    /// A one-off trigger at `date`, pinned to `calendar`'s time zone so it
    /// fires at that moment even if the phone's time zone changes.
    private static func trigger(at date: Date, in calendar: Calendar) -> UNCalendarNotificationTrigger {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.timeZone = calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    // MARK: In-use life

    /// The day before an opened pen or vial is due to be thrown away (or
    /// that day, if it's already the day before), at the refill time.
    private func discardRequest(for medicine: Medicine, settings: AppSettings, now: Date) -> UNNotificationRequest? {
        guard let discard = medicine.discardDate else { return nil }
        var fireDate = medicine.reminderTime.on(discard.adding(days: -1))
        if fireDate <= now { fireDate = medicine.reminderTime.on(discard) }
        guard fireDate > now else { return nil }
        let content = UNMutableNotificationContent()
        let name = settings.notificationName(for: medicine)
        content.title = Calendar.current.isDate(fireDate, inSameDayAs: discard) ? String(localized: "\(name): last day of use") : String(localized: "\(name): last day tomorrow")
        content.body = String(localized: "It’s been open since \(medicine.openedAt?.dayMonth ?? "a while"). Have a new one ready.")
        content.sound = .default
        content.threadIdentifier = medicine.id.uuidString
        content.userInfo = [Self.medicineIDKey: medicine.id.uuidString]
        return UNNotificationRequest(identifier: Prefix.discard + medicine.id.uuidString, content: content, trigger: Self.trigger(at: fireDate, in: .current))
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
