import SwiftUI

/// An injection's recent sites: the body map with the last site and the
/// suggested next one lit, then the last few injections and where they went.
struct InjectionSitesCard: View {
    @Environment(MedicineStore.self) private var store
    let medicine: Medicine
    let now: Date

    private static let recentCount = 5

    var body: some View {
        let history = store.injectionHistory(for: medicine.id)
        let suggested = store.suggestedSite()

        GroupedSection(
            title: "Injection sites",
            trailing: "Next: \(suggested.title)",
            footer: history.isEmpty ? "When you tick off an injection on Today, you pick where it went. Sites then rotate so each one gets a rest." : nil
        ) {
            BodyMap(selected: history.first?.site, suggested: suggested, lastUsed: store.lastUsed(), now: now)
                .frame(height: 220)
                .padding(.vertical, 16)
                .rowDivider(!history.isEmpty)
            ForEach(Array(history.prefix(Self.recentCount).enumerated()), id: \.element.id) { index, log in
                ValueRow(
                    title: log.site?.title ?? "",
                    value: log.takenAt.map { "\($0.weekdayDayMonth), \($0.clockTime)" },
                    showsDivider: index < min(history.count, Self.recentCount) - 1
                )
            }
        }
    }
}
