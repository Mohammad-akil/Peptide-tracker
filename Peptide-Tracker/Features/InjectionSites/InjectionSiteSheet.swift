import SwiftUI

/// "Where did you inject?" — opens when an injection is ticked off. The
/// body map starts on the suggested site; tapping the body or a chip picks
/// another, and Log dose ticks it off with the site. Skip ticks it off
/// without one.
struct InjectionSiteSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let dose: ScheduledDose
    @State private var selection: InjectionSite?

    var body: some View {
        let suggested = store.suggestedSite()
        let lastUsed = store.lastUsed()
        let site = selection ?? suggested
        let now = Date.now

        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Where did you inject?")
                        .font(.system(size: 22, weight: .bold))
                        .kerning(-0.2)
                    Text("\(dose.medicine.name) · \(dose.time.label)")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer()
                // The system close button: glass circle, xmark, "Close" for VoiceOver.
                Button(role: .close) { dismiss() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            BodyMap(selected: site, suggested: suggested, lastUsed: lastUsed, now: now) { picked in
                HapticFeedback.selection()
                withAnimation(.snappy) { selection = picked }
            }
            .frame(maxHeight: 300)
            .padding(.bottom, 12)

            note(for: site, suggested: suggested, lastUsed: lastUsed[site], now: now)
                .padding(.bottom, 14)

            SuggestionChips(
                options: InjectionSite.rotation.map(\.title),
                selection: Binding(
                    get: { site.title },
                    // Tapping the picked chip again keeps it picked.
                    set: { title in
                        if let picked = InjectionSite.allCases.first(where: { $0.title == title }) {
                            withAnimation(.snappy) { selection = picked }
                        }
                    }
                )
            )
            .padding(.bottom, 20)

            Button("Log dose · \(site.title)") { log(site) }
                .buttonStyle(.primary)
            Button("Skip site") { log(nil) }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(height: 44)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    /// Why the site is lit: suggested next, or used too recently.
    @ViewBuilder
    private func note(for site: InjectionSite, suggested: InjectionSite, lastUsed: Date?, now: Date) -> some View {
        Group {
            if BodyMap.isResting(lastUsed: lastUsed, now: now), let lastUsed {
                Label("Used \(lastUsed.relativeDay(now: now)). Try another site to let it rest.", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(Urgency.low.ink)
            } else if site == suggested {
                Label("Suggested next in your rotation", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(AppTheme.ColorToken.accentInk)
            } else if let lastUsed {
                Label("Last used \(lastUsed.relativeDay(now: now))", systemImage: "clock")
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            } else {
                Label("Not used yet", systemImage: "checkmark.circle")
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentTransition(.opacity)
    }

    private func log(_ site: InjectionSite?) {
        withAnimation(.snappy) { store.toggle(dose, site: site) }
        dismiss()
    }
}
