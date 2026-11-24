import SwiftUI

/// The calculators on Insights → Tools. Ported from Plates' nutrition
/// calculators (Mifflin-St Jeor BMR, TDEE, macros) plus BMI, trimmed to
/// general-wellness options with their sources shown — no crash-diet goals
/// and no "medical" diets, so nothing reads as treatment advice.
enum HealthCalculator: String, CaseIterable, Identifiable, Codable {
    case bmi, bmr, tdee, macros

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bmi: String(localized: "BMI")
        case .bmr: String(localized: "BMR")
        case .tdee: String(localized: "Daily calories")
        case .macros: String(localized: "Macros")
        }
    }

    var subtitle: String {
        switch self {
        case .bmi: String(localized: "Body mass index from height and weight")
        case .bmr: String(localized: "Calories your body burns at rest")
        case .tdee: String(localized: "Calories you burn in a day, with activity")
        case .macros: String(localized: "Protein, carbs and fat for a calorie goal")
        }
    }

    var symbol: String {
        switch self {
        case .bmi: "figure.stand"
        case .bmr: "bed.double.fill"
        case .tdee: "flame.fill"
        case .macros: "chart.pie.fill"
        }
    }

    var tint: Color {
        switch self {
        case .bmi: Color(hex: 0x0A84FF)
        case .bmr: Color(hex: 0x5E5CE6)
        case .tdee: Color(hex: 0xFF9F0A)
        case .macros: Color(hex: 0x30B0C7)
        }
    }

    /// "24.3" for BMI, "2,150 kcal" for the rest.
    func format(_ value: Double) -> String {
        self == .bmi
            ? value.formatted(.number.precision(.fractionLength(1)))
            : String(localized: "\(Int(value.rounded()).formatted()) kcal")
    }

    /// The drawn icon in Assets → Calculators ("calc-bmi" …).
    var illustration: Image { Image("calc-\(rawValue)") }

    var usesAgeAndSex: Bool { self != .bmi }
    var usesActivity: Bool { self == .tdee || self == .macros }

    /// Where the formula comes from (Guideline 1.4.1 asks health apps to
    /// cite their sources).
    var source: (title: String, url: URL) {
        switch self {
        case .bmi:
            (String(localized: "World Health Organization – BMI"), URL(string: "https://www.who.int/data/gho/data/themes/topics/topic-details/GHO/body-mass-index")!)
        case .bmr, .tdee, .macros:
            (String(localized: "Mifflin MD, St Jeor ST et al. Am J Clin Nutr, 1990"), URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!)
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive, extraActive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: String(localized: "Sedentary")
        case .light: String(localized: "Light")
        case .moderate: String(localized: "Moderate")
        case .active: String(localized: "Active")
        case .veryActive: String(localized: "Very active")
        case .extraActive: String(localized: "Extra active")
        }
    }

    var detail: String {
        switch self {
        case .sedentary: String(localized: "Little or no exercise")
        case .light: String(localized: "Exercise 1–3 times a week")
        case .moderate: String(localized: "Exercise 4–5 times a week")
        case .active: String(localized: "Daily, or intense 3–4 times a week")
        case .veryActive: String(localized: "Intense exercise 6–7 times a week")
        case .extraActive: String(localized: "Very intense daily, or a physical job")
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.465
        case .active: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }
}

/// Gentle goals only: no more than 0.5 kg (1 lb) a week either way.
enum CalorieGoal: String, CaseIterable, Identifiable {
    case loss, mildLoss, maintain, mildGain, gain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loss: String(localized: "Lose 0.5 kg (1 lb) a week")
        case .mildLoss: String(localized: "Lose 0.25 kg (0.5 lb) a week")
        case .maintain: String(localized: "Maintain weight")
        case .mildGain: String(localized: "Gain 0.25 kg (0.5 lb) a week")
        case .gain: String(localized: "Gain 0.5 kg (1 lb) a week")
        }
    }

    var adjustment: Int {
        switch self {
        case .loss: -500
        case .mildLoss: -250
        case .maintain: 0
        case .mildGain: 250
        case .gain: 500
        }
    }
}

/// Share of calories from protein, carbs and fat.
enum MacroSplit: String, CaseIterable, Identifiable {
    case balanced, highProtein, lowCarb, lowFat, mediterranean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: String(localized: "Balanced")
        case .highProtein: String(localized: "High protein")
        case .lowCarb: String(localized: "Low carb")
        case .lowFat: String(localized: "Low fat")
        case .mediterranean: String(localized: "Mediterranean")
        }
    }

    /// (protein, carbs, fat) in percent.
    var percentages: (protein: Int, carbs: Int, fat: Int) {
        switch self {
        case .balanced: (30, 50, 20)
        case .highProtein: (45, 25, 30)
        case .lowCarb: (25, 15, 60)
        case .lowFat: (25, 55, 20)
        case .mediterranean: (20, 50, 30)
        }
    }
}

// MARK: - Formulas

enum BodyMaths {
    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let metres = heightCm / 100
        return metres > 0 ? weightKg / (metres * metres) : 0
    }

    /// Mifflin-St Jeor.
    static func bmr(sex: BodySex, age: Int, heightCm: Double, weightKg: Double) -> Int {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return Int((sex == .male ? base + 5 : base - 161).rounded())
    }

    static func tdee(bmr: Int, activity: ActivityLevel) -> Int {
        Int((Double(bmr) * activity.multiplier).rounded())
    }

    /// Grams a day: protein and carbs at 4 kcal/g, fat at 9 kcal/g.
    static func macros(calories: Int, split: MacroSplit) -> (protein: Int, carbs: Int, fat: Int) {
        let p = split.percentages
        func grams(_ percent: Int, _ perGram: Double) -> Int {
            Int((Double(calories) * Double(percent) / 100 / perGram).rounded())
        }
        return (grams(p.protein, 4), grams(p.carbs, 4), grams(p.fat, 9))
    }
}

/// WHO adult BMI categories.
enum BMICategory: CaseIterable {
    case under, healthy, over, obese

    init(_ bmi: Double) {
        switch bmi {
        case ..<18.5: self = .under
        case ..<25: self = .healthy
        case ..<30: self = .over
        default: self = .obese
        }
    }

    var title: String {
        switch self {
        case .under: String(localized: "Underweight")
        case .healthy: String(localized: "Healthy range")
        case .over: String(localized: "Overweight")
        case .obese: String(localized: "Obesity")
        }
    }

    var range: String {
        switch self {
        case .under: String(localized: "Below 18.5")
        case .healthy: String(localized: "18.5 to 24.9")
        case .over: String(localized: "25 to 29.9")
        case .obese: String(localized: "30 and above")
        }
    }

    var tint: Color {
        switch self {
        case .under: Color(hex: 0xAF52DE)
        case .healthy: Color(hex: 0x1F8A4C)
        case .over: Color(hex: 0xB26A00)
        case .obese: Color(hex: 0xC8372D)
        }
    }
}
