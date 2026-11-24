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
    /// Onboarding GLP-1 questions: where the user is, how they take it and
    /// which medication (with the typed name when they chose Other).
    var glp1Journey: GLP1Journey?
    var glp1Route: GLP1Route?
    var glp1Medication: GLP1Medication?
    var glp1OtherMedication = ""
    /// The dose as a label ("0.5 mg", or what was typed under Other).
    var glp1Dose = ""
    /// Pen, auto-injector or syringe; nil for pills or when skipped.
    var glp1Device: GLP1Device?
    var glp1OtherDevice = ""
    /// Days between GLP-1 doses (1 to 21); nil when skipped.
    var glp1IntervalDays: Int?
    /// When the user started their GLP-1, from onboarding.
    var glp1StartDate: Date?
    /// Target weight from onboarding, in kilograms.
    var goalWeightKg: Double?
    /// Chosen pace toward the goal, kilograms a week.
    var weeklyGoalKg: Double?
    /// Side effects the user said they worry about, from onboarding.
    var sideEffectConcerns: Set<SideEffectConcern> = []
    var otherSideEffectConcern = ""
    /// Why the user wants to reach their goal, from onboarding.
    var goalReasons: Set<GoalReason> = []
    var otherGoalReason = ""
    /// Onboarding: whose medicines these are.
    var trackingFor = TrackingFor.me
    /// The person cared for — reminders use it ("Mum’s Metformin…").
    var personName = ""
    /// How refills arrive.
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
    /// A notification at each dose time, on the medicine's dose days.
    var doseReminders = true
    /// Injection areas left out of site rotation (e.g. no glutes when
    /// injecting yourself). Never every area; see `InjectionSite.next`.
    var skippedSiteAreas: Set<InjectionSite.Area> = []
    /// How weights are shown and entered; also picks metric or US units
    /// in the calculators.
    var weightUnit = WeightUnit.kg
    /// Remembered from the calculators so they open filled in.
    var heightCm: Double?
    var birthYear: Int?
    var sex: BodySex?
    /// A daily nudge to check the day's doses.
    var morningReminder = false
    var morningTime = TimeOfDay(hour: 8, minute: 0)
    /// A daily nudge before bed for any doses left.
    var sleepReminder = false
    var sleepTime = TimeOfDay(hour: 22, minute: 0)
    /// Privacy: Face ID (or the passcode) to open the app, and a blank
    /// screen in the app switcher.
    var appLock = false
    /// Travel: dose reminders stay at home time instead of following the
    /// clock of wherever the phone is.
    var keepsHomeTime = false
    /// The time zone doses are planned in while `keepsHomeTime` is on.
    var homeTimeZoneID: String?
    /// Sharps: count used needles toward a full container.
    var tracksSharps = false
    var sharpsCapacity = 100
    /// When the container was last emptied (or started); counting starts here.
    var sharpsEmptiedAt: Date?

    init() {}

    /// The time zone dose reminders are planned in.
    var doseTimeZone: TimeZone {
        guard keepsHomeTime, let id = homeTimeZoneID, let zone = TimeZone(identifier: id) else { return .current }
        return zone
    }

    /// What a reminder calls the medicine: its name (with whose it is), or
    /// "A medicine" when names are hidden from the lock screen.
    func notificationName(for medicine: Medicine) -> String {
        showsMedicineName ? reminderName(for: medicine) : String(localized: "A medicine")
    }

    /// The reminder's second line, with `{medicine}` filled in.
    func notificationMessage(for medicine: Medicine) -> String {
        let custom = reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !custom.isEmpty else { return String(localized: "Tap to refill.") }
        return custom.replacingOccurrences(of: "{medicine}", with: showsMedicineName ? medicine.name : String(localized: "your medicine"))
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
        case doseReminders, skippedSiteAreas
        case weightUnit, heightCm, birthYear, sex
        case appLock, keepsHomeTime, homeTimeZoneID
        case tracksSharps, sharpsCapacity, sharpsEmptiedAt
        case glp1Journey, glp1Route, glp1Medication, glp1OtherMedication, glp1Dose, glp1Device, glp1OtherDevice, glp1IntervalDays, glp1StartDate, goalWeightKg, weeklyGoalKg, sideEffectConcerns, otherSideEffectConcern, goalReasons, otherGoalReason
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
        doseReminders = try c.decodeIfPresent(Bool.self, forKey: .doseReminders) ?? defaults.doseReminders
        skippedSiteAreas = try c.decodeIfPresent(Set<InjectionSite.Area>.self, forKey: .skippedSiteAreas) ?? defaults.skippedSiteAreas
        weightUnit = try c.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? defaults.weightUnit
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        birthYear = try c.decodeIfPresent(Int.self, forKey: .birthYear)
        sex = try c.decodeIfPresent(BodySex.self, forKey: .sex)
        appLock = try c.decodeIfPresent(Bool.self, forKey: .appLock) ?? defaults.appLock
        keepsHomeTime = try c.decodeIfPresent(Bool.self, forKey: .keepsHomeTime) ?? defaults.keepsHomeTime
        homeTimeZoneID = try c.decodeIfPresent(String.self, forKey: .homeTimeZoneID)
        tracksSharps = try c.decodeIfPresent(Bool.self, forKey: .tracksSharps) ?? defaults.tracksSharps
        sharpsCapacity = try c.decodeIfPresent(Int.self, forKey: .sharpsCapacity) ?? defaults.sharpsCapacity
        sharpsEmptiedAt = try c.decodeIfPresent(Date.self, forKey: .sharpsEmptiedAt)
        glp1Journey = try c.decodeIfPresent(GLP1Journey.self, forKey: .glp1Journey)
        glp1Route = try c.decodeIfPresent(GLP1Route.self, forKey: .glp1Route)
        glp1Medication = try c.decodeIfPresent(GLP1Medication.self, forKey: .glp1Medication)
        glp1OtherMedication = try c.decodeIfPresent(String.self, forKey: .glp1OtherMedication) ?? defaults.glp1OtherMedication
        glp1Dose = try c.decodeIfPresent(String.self, forKey: .glp1Dose) ?? defaults.glp1Dose
        glp1Device = try c.decodeIfPresent(GLP1Device.self, forKey: .glp1Device)
        glp1OtherDevice = try c.decodeIfPresent(String.self, forKey: .glp1OtherDevice) ?? defaults.glp1OtherDevice
        glp1IntervalDays = try c.decodeIfPresent(Int.self, forKey: .glp1IntervalDays)
        glp1StartDate = try c.decodeIfPresent(Date.self, forKey: .glp1StartDate)
        goalWeightKg = try c.decodeIfPresent(Double.self, forKey: .goalWeightKg)
        weeklyGoalKg = try c.decodeIfPresent(Double.self, forKey: .weeklyGoalKg)
        sideEffectConcerns = try c.decodeIfPresent(Set<SideEffectConcern>.self, forKey: .sideEffectConcerns) ?? defaults.sideEffectConcerns
        otherSideEffectConcern = try c.decodeIfPresent(String.self, forKey: .otherSideEffectConcern) ?? defaults.otherSideEffectConcern
        goalReasons = try c.decodeIfPresent(Set<GoalReason>.self, forKey: .goalReasons) ?? defaults.goalReasons
        otherGoalReason = try c.decodeIfPresent(String.self, forKey: .otherGoalReason) ?? defaults.otherGoalReason
    }
}

/// Whose medicines these are.
enum TrackingFor: String, Codable, CaseIterable {
    case me, someoneElse, both

    var title: String {
        switch self {
        case .me: String(localized: "Just me")
        case .someoneElse: String(localized: "Someone I care for")
        case .both: String(localized: "Me and someone else")
        }
    }
}

/// How long a refill takes. Each answer sets how many days ahead the heads-up comes.
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

/// How refills arrive.
/// How long "Remind me later" on a refill reminder waits.
enum SnoozeOption: String, Codable, CaseIterable {
    case oneHour, threeHours, tomorrow

    var title: String {
        switch self {
        case .oneHour: String(localized: "1 hour")
        case .threeHours: String(localized: "3 hours")
        case .tomorrow: String(localized: "Tomorrow")
        }
    }

    /// The notification button: "Remind me in 1 hour", "Remind me tomorrow".
    var actionTitle: String {
        self == .tomorrow ? String(localized: "Remind me tomorrow") : String(localized: "Remind me in \(title)")
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
        case .one: String(localized: "One pharmacy")
        case .delivery: String(localized: "Delivery")
        case .varies: String(localized: "It varies")
        }
    }
}
