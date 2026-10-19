import Foundation

/// Date helpers and the short formats the design uses everywhere
/// ("Thu 1 Oct", "14 Oct", "20:00").
extension Calendar {
    func days(from start: Date, to end: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: start), to: startOfDay(for: end)).day ?? 0
    }
}

extension Date {
    func adding(days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    /// "14 Oct"
    var dayMonth: String { formatted(.dateTime.day().month(.abbreviated)) }
    /// "Fri 9 Oct"
    var weekdayDayMonth: String { formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
    /// "Thursday, 1 October"
    var longWeekdayDayMonth: String { formatted(.dateTime.weekday(.wide).day().month(.wide)) }
    /// "20:00" — the design always shows 24-hour times.
    var clockTime: String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: self)
        return TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0).label
    }
    /// "September"
    var monthName: String { formatted(.dateTime.month(.wide)) }
    /// "Sep"
    var monthAbbrev: String { formatted(.dateTime.month(.abbreviated)) }
    /// "today", "yesterday", "3 days ago"
    func relativeDay(now: Date = .now) -> String {
        let days = Calendar.current.days(from: self, to: now)
        switch days {
        case ...0: return "today"
        case 1: return "yesterday"
        default: return "\(days) days ago"
        }
    }
}

extension Int {
    /// "five", "twelve"
    var spelledOut: String {
        NumberFormatter.localizedString(from: NSNumber(value: self), number: .spellOut)
    }
}
