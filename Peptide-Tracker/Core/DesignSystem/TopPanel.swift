import SwiftUI

/// The pinned white panel at the top of a tab: a large title with its
/// actions, and whatever controls belong to the whole screen (Today's week,
/// Medicines' switch and search). Content scrolls underneath it.
struct TopPanel<Actions: View, Controls: View>: View {
    let title: String
    @ViewBuilder var actions: Actions
    @ViewBuilder var controls: Controls

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 30, weight: .heavy))
                    .kerning(-0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                actions
            }
            .padding(.horizontal, 20)

            controls
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
                .fill(AppTheme.ColorToken.cardBackground)
                .shadow(color: Color(hex: 0x28185A, opacity: 0.08), radius: 12, y: 6)
                // Runs up under the status bar.
                .ignoresSafeArea(edges: .top)
        }
    }
}
