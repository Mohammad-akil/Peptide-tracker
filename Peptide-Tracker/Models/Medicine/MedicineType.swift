import SwiftUI

/// What form a medicine comes in. The type sets the unit everywhere — the
/// Add form's labels, card chips, row subtitles and the reminder copy.
/// Case order is the order the type pickers show them in.
enum MedicineType: String, Codable, CaseIterable, Identifiable {
    case capsule, tablet, injection, liquid, drops, inhaler, powder, cream, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capsule: String(localized: "Pill")
        case .tablet: String(localized: "Tablet")
        case .injection: String(localized: "Injection")
        case .liquid: String(localized: "Liquid")
        case .drops: String(localized: "Drops")
        case .inhaler: String(localized: "Inhaler")
        case .powder: String(localized: "Powder")
        case .cream: String(localized: "Cream")
        case .other: String(localized: "Other")
        }
    }

    /// The filled SF Symbol for type pickers, and the tile glyph for types
    /// the asset pack doesn't draw.
    var symbol: String {
        switch self {
        case .capsule: "pills.fill"
        case .tablet: "pill.fill"
        case .injection: "syringe.fill"
        case .liquid: "waterbottle.fill"
        case .drops: "drop.fill"
        case .inhaler: "lungs.fill"
        case .powder: "aqi.medium"
        case .cream: "hands.and.sparkles.fill"
        case .other: "cross.case.fill"
        }
    }

    /// Each type's own Apple system colour, for its tile in type pickers.
    var tint: Color {
        switch self {
        case .capsule: Color(hex: 0x0A84FF)   // blue
        case .tablet: Color(hex: 0x5E5CE6)    // indigo
        case .injection: Color(hex: 0xFF375F) // pink
        case .liquid: Color(hex: 0x30B0C7)    // teal
        case .drops: Color(hex: 0x64D2FF)     // cyan
        case .inhaler: Color(hex: 0x30D158)   // green
        case .powder: Color(hex: 0xFF9F0A)    // orange
        case .cream: Color(hex: 0xBF5AF2)     // purple
        case .other: Color(hex: 0x8E8E93)     // grey
        }
    }

    /// Whether the asset pack has a drawn glyph for this type (the original
    /// six); the rest use `symbol`.
    var hasGlyph: Bool { ![.inhaler, .powder, .other].contains(self) }

    /// The asset-pack glyph, in the type's own colour.
    var glyph: Image { Image("type-\(rawValue)") }

    /// The glyph repainted in a medicine's tile colour.
    func glyph(in color: MedicineColor) -> Image { Image("type-\(rawValue)-\(color.rawValue)") }

    var unit: MedicineUnit {
        switch self {
        case .capsule: MedicineUnit(singular: String(localized: "pill", comment: "Medicine unit, one"), plural: String(localized: "pills", comment: "Medicine unit, many"))
        case .tablet: MedicineUnit(singular: String(localized: "tablet", comment: "Medicine unit, one"), plural: String(localized: "tablets", comment: "Medicine unit, many"))
        case .injection: MedicineUnit(singular: String(localized: "dose", comment: "Medicine unit, one"), plural: String(localized: "doses", comment: "Medicine unit, many"))
        case .cream: MedicineUnit(singular: String(localized: "application", comment: "Medicine unit, one"), plural: String(localized: "applications", comment: "Medicine unit, many"))
        case .liquid: MedicineUnit(singular: String(localized: "ml", comment: "Medicine unit, one"), plural: String(localized: "ml", comment: "Medicine unit, many"))
        case .drops: MedicineUnit(singular: String(localized: "drop", comment: "Medicine unit, one"), plural: String(localized: "drops", comment: "Medicine unit, many"))
        case .inhaler: MedicineUnit(singular: String(localized: "puff", comment: "Medicine unit, one"), plural: String(localized: "puffs", comment: "Medicine unit, many"))
        case .powder: MedicineUnit(singular: String(localized: "sachet", comment: "Medicine unit, one"), plural: String(localized: "sachets", comment: "Medicine unit, many"))
        case .other: MedicineUnit(singular: String(localized: "dose", comment: "Medicine unit, one"), plural: String(localized: "doses", comment: "Medicine unit, many"))
        }
    }

    /// "Pills in stock", "Doses in stock"…
    var stockLabel: String { String(localized: "\(unit.plural.capitalizedFirst) in stock") }

    /// "Pills per day", "Injections per day"…
    var perDayLabel: String {
        switch self {
        case .injection: String(localized: "Injections per day")
        default: String(localized: "\(unit.plural.capitalizedFirst) per day")
        }
    }

    /// Extra guidance under the supply section where counting isn't obvious.
    var supplyHint: String? {
        switch self {
        case .injection: String(localized: "Count single doses. A pen with 300 units at 15 units a dose is 20 doses.")
        case .liquid: String(localized: "Count millilitres. A 150 ml bottle at 5 ml a dose is 150 ml.")
        case .inhaler: String(localized: "Count puffs. Most inhalers show how many are left on a counter.")
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
        case .inhaler: [120, 200]
        case .powder: [10, 20, 30]
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

    /// Apple's bright system colours, for a solid tile behind a white glyph
    /// (the Medicines list). `slate` turns indigo, as grey isn't vibrant.
    var vibrant: Color {
        switch self {
        case .blue: Color(hex: 0x0A84FF)
        case .purple: Color(hex: 0xBF5AF2)
        case .pink: Color(hex: 0xFF375F)
        case .teal: Color(hex: 0x30B0C7)
        case .amber: Color(hex: 0xFF9F0A)
        case .slate: Color(hex: 0x5E5CE6)
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
