import SwiftUI

/// "No medicines yet" — the call to add the first one, and how the app
/// works.
struct EmptyCabinetView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            EmptyStateView(
                illustration: .emptyState,
                title: String(localized: "No medicines yet"),
                message: String(localized: "Add one and we’ll remind you before it runs out.")
            ) {
                Button("Add your first medicine", action: onAdd)
                    .buttonStyle(.primary(height: 52))
            }

            HowItWorksCard()
        }
    }
}

/// Three numbered steps: add, count down, heads-up.
struct HowItWorksCard: View {
    private let steps: [(title: String, detail: String)] = [
        (String(localized: "Add what you have"), String(localized: "How many you have now and how many you take a day.")),
        (String(localized: "We count down"), String(localized: "Your stock drops with each day’s doses.")),
        (String(localized: "Get a heads-up"), String(localized: "One reminder a few days before you run out.")),
    ]

    var body: some View {
        GroupedSection(title: String(localized: "How it works")) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.ColorToken.accentSoft, in: .circle)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title)
                            .font(.system(size: 17, weight: .semibold))
                        Text(step.detail)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 52)
                .rowDivider(index < steps.count - 1, inset: 58)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
