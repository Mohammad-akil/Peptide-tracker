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

    init() {}

    /// "Mum’s Metformin" when tracking for someone else, else "Metformin".
    func reminderName(for medicine: Medicine) -> String {
        let person = personName.trimmingCharacters(in: .whitespaces)
        guard trackingFor == .someoneElse, !person.isEmpty else { return medicine.name }
        return "\(person)’s \(medicine.name)"
    }

    private enum CodingKeys: String, CodingKey {
        case notificationsEnabled, defaultReminderTime, defaultDaysBefore
        case remindAgainUntilRefilled, tracksDoses, pharmacyName, pharmacyPhone
        case trackingFor, personName, pharmacyKind
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
