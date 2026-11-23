import SwiftUI

/// A choose-all-that-apply answer: SF Symbol, title, detail and the same
/// round check as single-choice answers, with optional fields underneath
/// when picked.
struct OnboardingMultiChoice<Detail: View>: View {
    let symbol: String
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                HapticFeedback.selection()
                withAnimation(.snappy) { action() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    RadioMark(isSelected: isSelected)
                }
                .multilineTextAlignment(.leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])

            detail
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground,
            in: .rect(cornerRadius: 20, style: .continuous)
        )
        .selectionBorder(isSelected, cornerRadius: 20)
    }
}
