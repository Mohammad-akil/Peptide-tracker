import Foundation

/// Which days a medicine is taken on. On those days the doses follow
/// `Medicine.intakeTimes`; every other day has none. Purely the user's own
/// schedule — the app never suggests one.
enum DoseFrequency: Codable, Hashable {
    case daily
    /// Every `n` days from the schedule's start day; 7 is weekly.
    case everyNDays(Int)
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday.
    case weekdays(Set<Int>)
    /// `on` days taking it, then `off` days without, repeating from the
    /// start day.
    case cycle(on: Int, off: Int)

    /// The kinds the picker offers, in order.
    enum Kind: CaseIterable, Identifiable {
        case daily, weekly, everyFewDays, weekdays, cycle

        var id: Self { self }

        var title: String {
            switch self {
            case .daily: "Every day"
            case .weekly: "Once a week"
            case .everyFewDays: "Every few days"
            case .weekdays: "On certain days"
            case .cycle: "Days on, days off"
            }
        }

        /// The schedule picking this kind starts with.
        var defaultFrequency: DoseFrequency {
            switch self {
            case .daily: .daily
            case .weekly: .everyNDays(7)
            case .everyFewDays: .everyNDays(2)
            case .weekdays: .weekdays([2, 4, 6])
            case .cycle: .cycle(on: 5, off: 2)
            }
        }

        /// Whether the schedule counts from a start day.
        var usesStartDay: Bool { self == .weekly || self == .everyFewDays || self == .cycle }
    }

    var kind: Kind {
        switch self {
        case .daily: .daily
        case .everyNDays(7): .weekly
        case .everyNDays: .everyFewDays
        case .weekdays: .weekdays
        case .cycle: .cycle
        }
    }

    var isDaily: Bool { self == .daily }

    /// Share of days that have doses: 1 daily, 1/7 weekly. Spreads the
    /// supply over calendar days for "days left".
    var doseDayFraction: Double {
        switch self {
        case .daily: 1
        case .everyNDays(let n): 1 / Double(max(n, 1))
        case .weekdays(let days): Double(max(days.count, 1)) / 7
        case .cycle(let on, let off): Double(max(on, 1)) / Double(max(on + off, 1))
        }
    }

    func isDoseDay(_ day: Date, start: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .daily:
            return true
        case .weekdays(let days):
            return days.contains(calendar.component(.weekday, from: day))
        case .everyNDays(let n):
            guard let offset = Self.days(from: start, to: day, calendar: calendar), offset >= 0 else { return false }
            return offset % max(n, 1) == 0
        case .cycle(let on, let off):
            guard let offset = Self.days(from: start, to: day, calendar: calendar), offset >= 0 else { return false }
            return offset % max(on + off, 1) < on
        }
    }

    // MARK: Copy

    /// "Every day", "Once a week", "Every 3 days", "Mon, Wed, Fri",
    /// "5 days on, 2 off".
    var title: String {
        switch self {
        case .daily: "Every day"
        case .everyNDays(7): "Once a week"
        case .everyNDays(let n): "Every \(n) days"
        case .weekdays(let days): Self.weekdayList(days)
        case .cycle(let on, let off): "\(on) days on, \(off) off"
        }
    }

    /// Monday first, as most of the world reads a week: (weekday, "Mon").
    static var weekdaysMondayFirst: [(day: Int, symbol: String)] {
        let symbols = Calendar.current.shortWeekdaySymbols
        return [2, 3, 4, 5, 6, 7, 1].map { (day: $0, symbol: symbols[$0 - 1]) }
    }

    static func weekdayList(_ days: Set<Int>) -> String {
        if days.count == 7 { return "Every day" }
        return weekdaysMondayFirst.filter { days.contains($0.day) }.map(\.symbol).joined(separator: ", ")
    }

    private static func days(from start: Date, to day: Date, calendar: Calendar) -> Int? {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: day)).day
    }
}
