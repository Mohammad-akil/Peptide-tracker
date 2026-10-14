import SwiftUI

/// "No medicines yet" — the call to add the first one, and how the app
/// works.
struct EmptyCabinetView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            EmptyStateView(
                illustration: .emptyState,
                title: "No medicines yet",
                message: "Add one and we’ll remind you before it runs out."
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
        ("Add what you have", "How many you have now and how many you take a day."),
        ("We count down", "Your stock drops with each day’s doses."),
        ("Get a heads-up", "One reminder a few days before you run out."),
    ]

    var body: some View {
        GroupedSection(title: "How it works") {
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
