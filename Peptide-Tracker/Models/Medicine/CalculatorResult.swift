import Foundation

/// A calculator answer the user chose to keep, so they can see the trend.
/// One per calculator per day; saving again that day replaces it.
struct CalculatorResult: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Start of the day it was saved.
    var day: Date
    var kind: HealthCalculator
    /// The BMI, or kcal a day for BMR, daily calories and macros.
    var value: Double
    /// The weight it was worked out from.
    var weightKg: Double?
    /// Grams a day, for macros.
    var protein: Int?
    var carbs: Int?
    var fat: Int?
}

/// How far back the history chart looks.
enum HistoryRange: String, CaseIterable, Identifiable {
    case threeMonths = "3M", sixMonths = "6M", nineMonths = "9M", year = "1Y", all = "All"

    var id: String { rawValue }
    var title: String { rawValue }

    var months: Int? {
        switch self {
        case .threeMonths: 3
        case .sixMonths: 6
        case .nineMonths: 9
        case .year: 12
        case .all: nil
        }
    }

    /// The first day in range, or nil for all time.
    func start(now: Date = .now) -> Date? {
        months.flatMap { Calendar.current.date(byAdding: .month, value: -$0, to: now.startOfDay) }
    }
}
