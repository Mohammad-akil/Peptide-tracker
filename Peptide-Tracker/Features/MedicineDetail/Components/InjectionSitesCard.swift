import SwiftUI

/// An injection's recent sites: the body map with the last site and the
/// suggested next one lit, then the last few injections and where they
/// went. The heatmap view shades each site by how often it was used in the
/// last 30 days, so overused spots stand out.
struct InjectionSitesCard: View {
    @Environment(MedicineStore.self) private var store
    let medicine: Medicine
    let now: Date
    @AppStorage("sites.showsHeatmap") private var showsHeatmap = false

    private static let recentCount = 5
    private static let heatDays = 30

    var body: some View {
        let history = store.injectionHistory(for: medicine.id)
        let suggested = store.suggestedSite()
        let heat = heatCounts(history)

        GroupedSection(
            title: String(localized: "Injection sites"),
            trailing: showsHeatmap ? String(localized: "Last \(Self.heatDays) days") : String(localized: "Next: \(suggested.title)"),
            footer: history.isEmpty ? String(localized: "When you tick off an injection on Today, you pick where it went. Sites then rotate so each one gets a rest.") : nil
        ) {
            if !history.isEmpty {
                Picker("View", selection: $showsHeatmap.animation(.snappy)) {
                    Text("Rotation").tag(false)
                    Text("Heatmap").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }

            BodyMap(
                selected: showsHeatmap ? nil : history.first?.site,
                suggested: showsHeatmap ? nil : suggested,
                lastUsed: showsHeatmap ? [:] : store.lastUsed(),
                now: now,
                heat: showsHeatmap ? heat : nil
            )
            .frame(height: 220)
            .padding(.vertical, 16)
            .rowDivider(!history.isEmpty)

            if showsHeatmap {
                heatRows(heat)
            } else {
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

    /// Injections per site over the heatmap window.
    private func heatCounts(_ history: [DoseLog]) -> [InjectionSite: Int] {
        let start = now.startOfDay.adding(days: -(Self.heatDays - 1))
        var counts: [InjectionSite: Int] = [:]
        for log in history where (log.takenAt ?? .distantPast) >= start {
            if let site = log.site { counts[site, default: 0] += 1 }
        }
        return counts
    }

    /// Each used site with its count and any reactions logged there.
    @ViewBuilder
    private func heatRows(_ heat: [InjectionSite: Int]) -> some View {
        let start = now.startOfDay.adding(days: -(Self.heatDays - 1))
        let reactions = Dictionary(grouping: store.sideEffects.filter { $0.kind == .siteReaction && $0.day >= start && $0.site != nil }, by: { $0.site! })
        let sites = InjectionSite.all.filter { (heat[$0] ?? 0) > 0 || reactions[$0] != nil }
            .sorted { (heat[$0] ?? 0) > (heat[$1] ?? 0) }
        if sites.isEmpty {
            Text("No injections with a site in the last \(Self.heatDays) days.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        ForEach(Array(sites.enumerated()), id: \.element) { index, site in
            let count = heat[site] ?? 0
            let reactionCount = reactions[site]?.count ?? 0
            HStack(spacing: 10) {
                Text(site.title).font(.system(size: 17))
                if reactionCount > 0 {
                    Chip(text: reactionCount == 1 ? String(localized: "1 reaction") : String(localized: "\(reactionCount) reactions"), foreground: Urgency.critical.ink, background: Urgency.critical.wash, bold: true)
                }
                Spacer(minLength: 8)
                Text("\(count)×")
                    .font(.system(size: 17))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .rowDivider(index < sites.count - 1)
        }
    }
}
