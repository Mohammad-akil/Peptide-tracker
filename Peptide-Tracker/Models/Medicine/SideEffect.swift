import SwiftUI

/// Something the user noticed on a day — nausea, a headache, a sore
/// injection site — logged so patterns show up and the doctor sees them.
/// Descriptive only: the app never says what caused it or what to do.
struct SideEffectEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    /// When it was noticed.
    var date: Date
    var kind: Kind
    var severity: Severity
    /// The medicine the user links it to, if any.
    var medicineID: UUID?
    /// For a site reaction: which site.
    var site: InjectionSite?
    var note = ""

    var day: Date { date.startOfDay }

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case nausea, fatigue, headache, appetite, constipation, diarrhea, dizziness, sleep, siteReaction, other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .nausea: "Nausea"
            case .fatigue: "Tiredness"
            case .headache: "Headache"
            case .appetite: "Low appetite"
            case .constipation: "Constipation"
            case .diarrhea: "Diarrhoea"
            case .dizziness: "Dizziness"
            case .sleep: "Poor sleep"
            case .siteReaction: "Site reaction"
            case .other: "Other"
            }
        }

        var symbol: String {
            switch self {
            case .nausea: "face.dashed"
            case .fatigue: "battery.25"
            case .headache: "brain.head.profile"
            case .appetite: "fork.knife"
            case .constipation, .diarrhea: "stomach"
            case .dizziness: "tornado"
            case .sleep: "bed.double.fill"
            case .siteReaction: "bandage.fill"
            case .other: "ellipsis.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .nausea: Color(hex: 0x30D158)
            case .fatigue: Color(hex: 0xFF9F0A)
            case .headache: Color(hex: 0xFF453A)
            case .appetite: Color(hex: 0xFFD60A)
            case .constipation, .diarrhea: Color(hex: 0xA2845E)
            case .dizziness: Color(hex: 0x64D2FF)
            case .sleep: Color(hex: 0x5E5CE6)
            case .siteReaction: Color(hex: 0xFF375F)
            case .other: Color(hex: 0x8E8E93)
            }
        }
    }

    enum Severity: Int, Codable, CaseIterable, Identifiable, Comparable {
        case mild = 1, moderate, severe

        var id: Int { rawValue }
        var title: String {
            switch self {
            case .mild: "Mild"
            case .moderate: "Moderate"
            case .severe: "Severe"
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}

// MARK: - Patterns

/// "Nausea is most often logged 1 day after a dose (4 of 6 times)" — how
/// each kind of side effect sits relative to the dose before it. Only
/// describes what was logged; it never claims a cause.
struct SideEffectPattern: Identifiable {
    let kind: SideEffectEntry.Kind
    let count: Int
    /// Days after the dose before it that this kind is most often logged.
    let typicalOffset: Int?
    /// How many entries fell on `typicalOffset`.
    let offsetCount: Int
    let medicineName: String?

    var id: String { kind.rawValue }

    /// The sentence shown on the card.
    var sentence: String {
        guard let typicalOffset, offsetCount >= 2 else {
            return "\(kind.title) logged \(count) \(count == 1 ? "time" : "times")."
        }
        let when = switch typicalOffset {
        case 0: "on dose days"
        case 1: "the day after a dose"
        default: "\(typicalOffset) days after a dose"
        }
        let dose = medicineName.map { " of \($0)" } ?? ""
        return "\(kind.title) is most often logged \(when)\(dose) (\(offsetCount) of \(count) times)."
    }

    /// Patterns over `entries`, most frequent first. `doseDays` are the days
    /// each medicine was taken, used to measure "days after a dose".
    static func patterns(
        entries: [SideEffectEntry],
        doseDays: [UUID: [Date]],
        medicineNames: [UUID: String]
    ) -> [SideEffectPattern] {
        Dictionary(grouping: entries, by: \.kind)
            .map { kind, group in
                // Measure against the medicine linked most often, else the
                // one with the fewest dose days (weekly shots tell the most).
                let linked = Dictionary(grouping: group.compactMap(\.medicineID), by: { $0 })
                    .max { $0.value.count < $1.value.count }?.key
                let fallback = doseDays.filter { !$0.value.isEmpty }.min { $0.value.count < $1.value.count }?.key
                let medicineID = linked ?? fallback
                let days = medicineID.flatMap { doseDays[$0] }?.sorted() ?? []

                var offsets: [Int: Int] = [:]
                for entry in group {
                    guard let previous = days.last(where: { $0 <= entry.day }) else { continue }
                    let offset = Calendar.current.days(from: previous, to: entry.day)
                    guard offset <= 6 else { continue }
                    offsets[offset, default: 0] += 1
                }
                let top = offsets.max { ($0.value, -$0.key) < ($1.value, -$1.key) }
                return SideEffectPattern(
                    kind: kind,
                    count: group.count,
                    typicalOffset: top?.key,
                    offsetCount: top?.value ?? 0,
                    medicineName: medicineID.flatMap { medicineNames[$0] }
                )
            }
            .sorted { ($0.count, $0.kind.title) > ($1.count, $1.kind.title) }
    }
}
