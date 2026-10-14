import SwiftUI

/// What form a medicine comes in. The type sets the unit everywhere — the
/// Add form's labels, card chips, row subtitles and the reminder copy.
enum MedicineType: String, Codable, CaseIterable, Identifiable {
    case capsule, tablet, injection, cream, liquid, drops

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capsule: "Capsule"
        case .tablet: "Tablet"
        case .injection: "Injection"
        case .cream: "Cream"
        case .liquid: "Liquid"
        case .drops: "Drops"
        }
    }

    /// The line icon on the Add form's type picker.
    var icon: AppIcon {
        switch self {
        case .capsule: .pill
        case .tablet: .round
        case .injection: .syringe
        case .cream: .cream
        case .liquid: .liquid
        case .drops: .drop
        }
    }

    /// The asset-pack glyph, in the type's own colour.
    var glyph: Image { Image("type-\(rawValue)") }

    /// The glyph repainted in a medicine's tile colour.
    func glyph(in color: MedicineColor) -> Image { Image("type-\(rawValue)-\(color.rawValue)") }

    var unit: MedicineUnit {
        switch self {
        case .capsule: MedicineUnit(singular: "pill", plural: "pills")
        case .tablet: MedicineUnit(singular: "tablet", plural: "tablets")
        case .injection: MedicineUnit(singular: "dose", plural: "doses")
        case .cream: MedicineUnit(singular: "application", plural: "applications")
        case .liquid: MedicineUnit(singular: "ml", plural: "ml")
        case .drops: MedicineUnit(singular: "drop", plural: "drops")
        }
    }

    /// "Pills in stock", "Doses in stock"…
    var stockLabel: String { "\(unit.plural.capitalizedFirst) in stock" }

    /// "Pills per day", "Injections per day"…
    var perDayLabel: String {
        switch self {
        case .injection: "Injections per day"
        default: "\(unit.plural.capitalizedFirst) per day"
        }
    }

    /// Extra guidance under the supply section where counting isn't obvious.
    var supplyHint: String? {
        switch self {
        case .injection: "Count single doses. A pen with 300 units at 15 units a dose is 20 doses."
        case .liquid: "Count millilitres. A 150 ml bottle at 5 ml a dose is 150 ml."
        default: nil
        }
    }

    /// Typical pack sizes offered on the refill sheet.
    var commonPackSizes: [Int] {
        switch self {
        case .injection: [5, 10, 20]
        case .cream: [30, 60, 100]
        case .liquid: [100, 150, 200]
        case .drops: [100, 200, 300]
        default: [30, 60, 90]
        }
    }
}

struct MedicineUnit: Hashable {
    let singular: String
    let plural: String

    func name(for count: Int) -> String { count == 1 ? singular : plural }

    /// "26 pills", "1 tablet", "150 ml"
    func format(_ count: Int) -> String { "\(count) \(name(for: count))" }
}

/// The six tile colours offered in the Add form.
enum MedicineColor: String, Codable, CaseIterable, Identifiable {
    case blue, purple, pink, teal, amber, slate

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: Color(hex: 0x2C5FC4)
        case .purple: Color(hex: 0x8A4FD6)
        case .pink: Color(hex: 0xD2558E)
        case .teal: Color(hex: 0x22769A)
        case .amber: Color(hex: 0xA65A2A)
        case .slate: Color(hex: 0x5A6577)
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
