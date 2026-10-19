import Foundation

/// One intake of one medicine on one day. A log only exists once the dose
/// is accounted for: ticked off by the user (`takenAt` set), or counted
/// down automatically at day's end (`takenAt` nil) so stock stays honest
/// even when the user forgets to tick.
struct DoseLog: Identifiable, Codable, Hashable {
    var id = UUID()
    var medicineID: UUID
    /// Start of the day the dose belongs to.
    var day: Date
    var time: TimeOfDay
    var units: Int
    var takenAt: Date?
    /// Where an injection went, when the user picked a site.
    var site: InjectionSite?

    var isTaken: Bool { takenAt != nil }
}

/// Units added to a medicine's supply.
struct RefillEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var medicineID: UUID
    /// Kept so history still reads well after the medicine is renamed.
    var medicineName: String
    var date: Date
    var amount: Int
    /// How long this refill lasts at the daily amount when it was made.
    var lastsDays: Int
}

/// A dose the user should take on a given day, resolved against the logs.
struct ScheduledDose: Identifiable, Hashable {
    let medicine: Medicine
    let day: Date
    let time: TimeOfDay
    let takenAt: Date?
    var site: InjectionSite? = nil

    var id: String { "\(medicine.id)-\(day.timeIntervalSince1970)-\(time.minutesSinceMidnight)" }
    var isTaken: Bool { takenAt != nil }
    var scheduledAt: Date { time.on(day) }
}

/// User preferences that shape reminders and dose tracking.
struct AppSettings: Codable, Hashable {
    var notificationsEnabled = true
    var defaultReminderTime = TimeOfDay.defaultReminder
    var defaultDaysBefore = 5
    /// Repeat the heads-up each morning until the medicine is marked
    /// ordered or refilled.
    var remindAgainUntilRefilled = true
    /// Show doses on Today to tick off. Off: stock counts down from the
    /// schedule alone.
    var tracksDoses = true
    var pharmacyName = ""
    var pharmacyPhone = ""
    /// Onboarding Q1: whose medicines these are.
    var trackingFor = TrackingFor.me
    /// The person cared for — reminders use it ("Mum’s Metformin…").
    var personName = ""
    /// Onboarding Q5: how refills arrive.
    var pharmacyKind = PharmacyKind.one
    /// The user's own name, shown on their profile in Settings.
    var userName = ""
    /// The line under a reminder's title; empty uses "Tap to refill.".
    /// `{medicine}` is replaced with the medicine's name.
    var reminderMessage = ""
    /// Off keeps names off the lock screen ("A medicine runs out in 3 days").
    var showsMedicineName = true
    /// How long "Remind me later" on a notification waits.
    var snooze = SnoozeOption.tomorrow
    /// A daily nudge to check the day's doses.
    var morningReminder = false
    var morningTime = TimeOfDay(hour: 8, minute: 0)
    /// A daily nudge before bed for any doses left.
    var sleepReminder = false
    var sleepTime = TimeOfDay(hour: 22, minute: 0)

    init() {}

    /// What a reminder calls the medicine: its name (with whose it is), or
    /// "A medicine" when names are hidden from the lock screen.
    func notificationName(for medicine: Medicine) -> String {
        showsMedicineName ? reminderName(for: medicine) : "A medicine"
    }

    /// The reminder's second line, with `{medicine}` filled in.
    func notificationMessage(for medicine: Medicine) -> String {
        let custom = reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !custom.isEmpty else { return "Tap to refill." }
        return custom.replacingOccurrences(of: "{medicine}", with: showsMedicineName ? medicine.name : "your medicine")
    }

    /// "Mum’s Metformin" when tracking for someone else, else "Metformin".
    func reminderName(for medicine: Medicine) -> String {
        let person = personName.trimmingCharacters(in: .whitespaces)
        guard trackingFor == .someoneElse, !person.isEmpty else { return medicine.name }
        return "\(person)’s \(medicine.name)"
    }

    private enum CodingKeys: String, CodingKey {
        case notificationsEnabled, defaultReminderTime, defaultDaysBefore
        case remindAgainUntilRefilled, tracksDoses, pharmacyName, pharmacyPhone
        case trackingFor, personName, pharmacyKind, userName
        case reminderMessage, showsMedicineName, snooze
        case morningReminder, morningTime, sleepReminder, sleepTime
    }

    /// Tolerates keys added in later versions, so an older save still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? defaults.notificationsEnabled
        defaultReminderTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .defaultReminderTime) ?? defaults.defaultReminderTime
        defaultDaysBefore = try c.decodeIfPresent(Int.self, forKey: .defaultDaysBefore) ?? defaults.defaultDaysBefore
        remindAgainUntilRefilled = try c.decodeIfPresent(Bool.self, forKey: .remindAgainUntilRefilled) ?? defaults.remindAgainUntilRefilled
        tracksDoses = try c.decodeIfPresent(Bool.self, forKey: .tracksDoses) ?? defaults.tracksDoses
        pharmacyName = try c.decodeIfPresent(String.self, forKey: .pharmacyName) ?? defaults.pharmacyName
        pharmacyPhone = try c.decodeIfPresent(String.self, forKey: .pharmacyPhone) ?? defaults.pharmacyPhone
        trackingFor = try c.decodeIfPresent(TrackingFor.self, forKey: .trackingFor) ?? defaults.trackingFor
        personName = try c.decodeIfPresent(String.self, forKey: .personName) ?? defaults.personName
        pharmacyKind = try c.decodeIfPresent(PharmacyKind.self, forKey: .pharmacyKind) ?? defaults.pharmacyKind
        userName = try c.decodeIfPresent(String.self, forKey: .userName) ?? defaults.userName
        reminderMessage = try c.decodeIfPresent(String.self, forKey: .reminderMessage) ?? defaults.reminderMessage
        showsMedicineName = try c.decodeIfPresent(Bool.self, forKey: .showsMedicineName) ?? defaults.showsMedicineName
        snooze = try c.decodeIfPresent(SnoozeOption.self, forKey: .snooze) ?? defaults.snooze
        morningReminder = try c.decodeIfPresent(Bool.self, forKey: .morningReminder) ?? defaults.morningReminder
        morningTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .morningTime) ?? defaults.morningTime
        sleepReminder = try c.decodeIfPresent(Bool.self, forKey: .sleepReminder) ?? defaults.sleepReminder
        sleepTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .sleepTime) ?? defaults.sleepTime
    }
}

/// Onboarding Q1.
enum TrackingFor: String, Codable, CaseIterable {
    case me, someoneElse, both

    var title: String {
        switch self {
        case .me: "Just me"
        case .someoneElse: "Someone I care for"
        case .both: "Me and someone else"
        }
    }
}

/// Onboarding Q2. Each answer sets how many days ahead the heads-up comes.
enum RefillLeadTime: CaseIterable {
    case sameDay, oneToTwoDays, threeToFiveDays, weekOrMore

    var daysBefore: Int {
        switch self {
        case .sameDay: 3
        case .oneToTwoDays: 5
        case .threeToFiveDays: 7
        case .weekOrMore: 10
        }
    }

    init(daysBefore: Int) {
        self = Self.allCases.last { $0.daysBefore <= daysBefore } ?? .sameDay
    }
}

/// Onboarding Q5.
/// How long "Remind me later" on a refill reminder waits.
enum SnoozeOption: String, Codable, CaseIterable {
    case oneHour, threeHours, tomorrow

    var title: String {
        switch self {
        case .oneHour: "1 hour"
        case .threeHours: "3 hours"
        case .tomorrow: "Tomorrow"
        }
    }

    /// The notification button: "Remind me in 1 hour", "Remind me tomorrow".
    var actionTitle: String {
        self == .tomorrow ? "Remind me tomorrow" : "Remind me in \(title)"
    }

    /// When the snoozed reminder comes back: later today, or tomorrow at
    /// the medicine's reminder time.
    func date(from now: Date, reminderTime: TimeOfDay) -> Date {
        switch self {
        case .oneHour: now.addingTimeInterval(3600)
        case .threeHours: now.addingTimeInterval(3 * 3600)
        case .tomorrow: reminderTime.on(now.startOfDay.adding(days: 1))
        }
    }
}

enum PharmacyKind: String, Codable, CaseIterable {
    case one, delivery, varies

    var title: String {
        switch self {
        case .one: "One pharmacy"
        case .delivery: "Delivery"
        case .varies: "It varies"
        }
    }
}
