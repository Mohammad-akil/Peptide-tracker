import SwiftUI

/// A medicine in the user's cabinet: what it is, how much is left and how
/// fast it's used. Everything the app shows about running out is derived
/// from `stock` and `perDay`.
struct Medicine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// Free text like "500 mg" or "100 u/ml". Optional.
    var strength: String
    var type: MedicineType
    var color: MedicineColor
    /// Units on hand right now.
    var stock: Int
    /// The fullest the supply has been — the ring's 100% and the "of 60".
    var capacity: Int
    /// Units used per day across every intake.
    var perDay: Int
    /// When doses are taken. Each intake uses `unitsPerIntake`.
    var intakeTimes: [TimeOfDay]
    var reminderDaysBefore: Int
    var reminderTime: TimeOfDay
    var remindersPaused = false
    /// Set when a refill is ordered; reminders pause until it's picked up
    /// and marked refilled.
    var orderedAt: Date?
    var createdAt = Date()
    /// The brand on the box ("Glucophage"), when it differs from the name.
    var brandName = ""
    /// What it's for ("Blood pressure"). Optional.
    var reason = ""
    /// How to take it ("With food"). Optional.
    var instructions = ""
    /// The user's own word for the type, when it's `.other` ("Patch").
    var customTypeName = ""
    /// Units ticked off today. Not saved — the store derives it from the
    /// dose logs — but kept here so days left stays put while today's doses
    /// are taken, instead of dropping a day every evening.
    var unitsTakenToday = 0

    private enum CodingKeys: String, CodingKey {
        case id, name, strength, type, color, stock, capacity, perDay, intakeTimes
        case reminderDaysBefore, reminderTime, remindersPaused, orderedAt, createdAt
        case brandName, reason, instructions, customTypeName
    }

    var unit: MedicineUnit { type.unit }

    /// "Inhaler", or the user's own name for an Other type.
    var typeTitle: String {
        let custom = customTypeName.trimmingCharacters(in: .whitespaces)
        return type == .other && !custom.isEmpty ? custom : type.title
    }

    var unitsPerIntake: Int { max(1, perDay / max(intakeTimes.count, 1)) }

    /// Days covered counting from the start of today: the stock this morning
    /// divided by the daily amount.
    var daysLeft: Int { perDay > 0 ? (stock + unitsTakenToday) / perDay : 0 }

    /// Out when there isn't enough left for the next dose.
    var urgency: Urgency { Urgency(daysLeft: daysLeft, isOut: stock < unitsPerIntake) }

    var isOrdered: Bool { orderedAt != nil }

    /// Whether to send the heads-up at all: not while paused, ordered or out.
    var wantsReminder: Bool { !remindersPaused && !isOrdered && stock > 0 }

    /// Fraction of `capacity` still on hand, for rings and bars.
    var stockFraction: Double { capacity > 0 ? Double(stock) / Double(capacity) : 0 }

    /// The day the supply runs out, counting from `now`.
    func runOutDate(now: Date = .now) -> Date {
        now.startOfDay.adding(days: daysLeft)
    }

    /// When the heads-up notification fires.
    func reminderDate(now: Date = .now) -> Date {
        let day = runOutDate(now: now).adding(days: -reminderDaysBefore)
        return reminderTime.on(day)
    }

    // MARK: Copy

    /// "500 mg · 2 a day"
    var cardSubtitle: String {
        [strength, "\(perDay) a day"].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "500 mg · 2 pills a day"
    var detailSubtitle: String {
        [strength, "\(unit.format(perDay)) a day"].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "Twice daily"
    var scheduleTitle: String {
        switch intakeTimes.count {
        case 0, 1: "Once daily"
        case 2: "Twice daily"
        default: "\(intakeTimes.count) times daily"
        }
    }

    /// "13 days", "1 day", "Run out"
    var daysLeftLabel: String {
        urgency == .out ? "Run out" : "\(daysLeft) \(daysLeft == 1 ? "day" : "days")"
    }

    /// "8:00 · 20:00"
    var scheduleTimes: String { intakeTimes.map(\.label).joined(separator: " · ") }

    /// "8:00 and 20:00", "8:00, 14:00 and 20:00"
    var scheduleList: String {
        let labels = intakeTimes.map(\.label)
        guard labels.count > 1 else { return labels.first ?? "" }
        return labels.dropLast().joined(separator: ", ") + " and " + labels.last!
    }
}

// MARK: - Decoding

extension Medicine {
    /// Medicines saved before the brand, reason, instructions and custom
    /// type fields existed load with those left empty.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        strength = try c.decode(String.self, forKey: .strength)
        type = try c.decode(MedicineType.self, forKey: .type)
        color = try c.decode(MedicineColor.self, forKey: .color)
        stock = try c.decode(Int.self, forKey: .stock)
        capacity = try c.decode(Int.self, forKey: .capacity)
        perDay = try c.decode(Int.self, forKey: .perDay)
        intakeTimes = try c.decode([TimeOfDay].self, forKey: .intakeTimes)
        reminderDaysBefore = try c.decode(Int.self, forKey: .reminderDaysBefore)
        reminderTime = try c.decode(TimeOfDay.self, forKey: .reminderTime)
        remindersPaused = try c.decodeIfPresent(Bool.self, forKey: .remindersPaused) ?? false
        orderedAt = try c.decodeIfPresent(Date.self, forKey: .orderedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        brandName = try c.decodeIfPresent(String.self, forKey: .brandName) ?? ""
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        customTypeName = try c.decodeIfPresent(String.self, forKey: .customTypeName) ?? ""
    }
}

// MARK: - Urgency

/// How soon a medicine runs out, and the colour that says so. The design's
/// legend: 10d+ green, 5–10d amber, under 5d red.
enum Urgency: Int, Comparable {
    case out, critical, low, healthy

    init(daysLeft: Int, isOut: Bool) {
        if isOut { self = .out }
        else if daysLeft < 5 { self = .critical }
        else if daysLeft < 10 { self = .low }
        else { self = .healthy }
    }

    static func < (lhs: Urgency, rhs: Urgency) -> Bool { lhs.rawValue < rhs.rawValue }

    var isRunningLow: Bool { self != .healthy }

    /// Strong tone for rings, bars and big numbers.
    var tint: Color {
        switch self {
        case .out, .critical: Color(hex: 0xC8372D)
        case .low: Color(hex: 0xB26A00)
        case .healthy: Color(hex: 0x1F8A4C)
        }
    }

    /// Text on `wash`.
    var ink: Color {
        switch self {
        case .out, .critical: Color(light: 0xA42A21, dark: 0xFF9C92)
        case .low: Color(light: 0x8A5200, dark: 0xF3C27A)
        case .healthy: Color(light: 0x17693A, dark: 0x8EDDA9)
        }
    }

    /// Pale chip and banner background.
    var wash: Color {
        switch self {
        case .out, .critical: Color(light: 0xFBE5E2, dark: 0x3D1F1C)
        case .low: Color(light: 0xFCF0DA, dark: 0x3A2C14)
        case .healthy: Color(light: 0xE2F3E8, dark: 0x163222)
        }
    }
}

// MARK: - Time of day

/// A wall-clock time with no date, e.g. a dose at 20:00.
struct TimeOfDay: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    static let morning = TimeOfDay(hour: 8, minute: 0)
    static let defaultReminder = TimeOfDay(hour: 9, minute: 0)

    var minutesSinceMidnight: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    /// "8:00", "20:00"
    var label: String { "\(hour):" + String(format: "%02d", minute) }

    /// "Morning", "Evening"…
    var periodName: String {
        switch hour {
        case 5..<12: "Morning"
        case 12..<17: "Afternoon"
        case 17..<21: "Evening"
        default: "Night"
        }
    }

    func on(_ day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// Spreads a daily amount over sensible intake times. Uses the most
    /// intakes (up to four) that divide the amount evenly, so each intake is
    /// a whole number of units.
    static func defaultSchedule(perDay: Int) -> [TimeOfDay] {
        let count = [4, 3, 2, 1].first { $0 <= max(perDay, 1) && max(perDay, 1) % $0 == 0 } ?? 1
        return schedule(count: count)
    }

    /// Evenly spaced waking-hours times for a number of doses a day (1–4).
    static func schedule(count: Int) -> [TimeOfDay] {
        switch count {
        case 4: return [.init(hour: 8, minute: 0), .init(hour: 12, minute: 0), .init(hour: 16, minute: 0), .init(hour: 20, minute: 0)]
        case 3: return [.init(hour: 8, minute: 0), .init(hour: 14, minute: 0), .init(hour: 20, minute: 0)]
        case 2: return [.init(hour: 8, minute: 0), .init(hour: 20, minute: 0)]
        default: return [.morning]
        }
    }
}
