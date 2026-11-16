import Foundation

/// One weigh-in. Always stored in kilograms; shown in the user's unit.
struct WeightEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Start of the day it was logged for; one entry per day.
    var day: Date
    var kilograms: Double
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kg, lb

    var id: String { rawValue }
    var title: String { rawValue }

    static let poundsPerKilogram = 2.20462262

    /// Kilograms in this unit.
    func value(fromKilograms kg: Double) -> Double {
        self == .kg ? kg : kg * Self.poundsPerKilogram
    }

    /// This unit's value in kilograms.
    func kilograms(from value: Double) -> Double {
        self == .kg ? value : value / Self.poundsPerKilogram
    }

    /// "72.4 kg", "159.6 lb"
    func format(_ kg: Double) -> String {
        "\(value(fromKilograms: kg).formatted(.number.precision(.fractionLength(1)))) \(rawValue)"
    }
}

/// For the calorie calculators (Mifflin-St Jeor uses it).
enum BodySex: String, Codable, CaseIterable, Identifiable {
    case female, male

    var id: String { rawValue }
    var title: String { self == .female ? "Female" : "Male" }
}
