import SwiftUI

/// Back, a five-step progress bar and Skip — the frame every question and
/// the summary share.
struct OnboardingTopBar: View {
    /// How many of the five segments are filled.
    let progress: Int
    let onBack: () -> Void
    /// Hidden on screens that aren't questions (the benefit chart, the plan).
    var onSkip: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Icon(.chev, size: 22)
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Back")

            HStack(spacing: 5) {
                ForEach(0..<OnboardingStep.questionCount, id: \.self) { index in
                    Capsule()
                        .fill(index < progress ? AppTheme.ColorToken.accent : Color(hex: 0x767680, opacity: 0.18))
                        .frame(height: 5)
                }
            }
            .padding(.horizontal, 14)
            .animation(.snappy, value: progress)
            .accessibilityElement()
            .accessibilityLabel("Setup progress")
            .accessibilityValue("\(progress) of \(OnboardingStep.questionCount)")

            if let onSkip {
                Button("Skip", action: onSkip)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .padding(.horizontal, 4)
                    .frame(height: 44)
            } else {
                Color.clear.frame(width: 40, height: 44)
            }
        }
        .padding(.horizontal, 16)
    }
}

/// "Question 2 of 5", the question, and why we ask it.
struct OnboardingHeader: View {
    let eyebrow: String
    let title: String
    var reason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
            Text(title)
                .font(.system(size: 30, weight: .heavy))
                .kerning(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
            if let reason {
                Text(reason)
                    .font(.system(size: 16))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One answer: icon, title, a line of detail and a radio. Extra fields for
/// the chosen answer (a name, a pharmacy) open underneath.
struct OnboardingChoice<Detail: View>: View {
    let icon: AppIcon
    let title: String
    let subtitle: String
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
                    Icon(icon, size: 21)
                        .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                        .frame(width: 42, height: 42)
                        .background(
                            isSelected ? AppTheme.ColorToken.accentSoft : Color(hex: 0x767680, opacity: 0.1),
                            in: .rect(cornerRadius: 13, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
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
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isSelected ? AppTheme.ColorToken.accent : Color(hex: 0x28185A, opacity: 0.08),
                    lineWidth: isSelected ? 2 : 0.5
                )
        }
    }
}

extension OnboardingChoice where Detail == EmptyView {
    init(icon: AppIcon, title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) {
        self.init(icon: icon, title: title, subtitle: subtitle, isSelected: isSelected, action: action) { EmptyView() }
    }
}

struct RadioMark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle().fill(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.cardBackground)
            Circle().strokeBorder(isSelected ? AppTheme.ColorToken.accent : Color(light: 0xCBC6D9, dark: 0x4C4858), lineWidth: 2)
            if isSelected {
                Icon(.check, size: 15).foregroundStyle(.white)
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

/// A labelled text field inside an opened choice ("Their name").
struct OnboardingField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
            TextField(label, text: $text, prompt: Text(placeholder))
                .font(.system(size: 17))
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color(hex: 0x767680, opacity: 0.1), in: .rect(cornerRadius: 12, style: .continuous))
        }
    }
}

/// The lilac note above Continue ("We’ll remind you 5 days before…").
struct OnboardingNote: View {
    let icon: AppIcon
    let text: Text

    var body: some View {
        HStack(spacing: 10) {
            Icon(icon, size: 19).foregroundStyle(AppTheme.ColorToken.accent)
            text
                .font(.system(size: 15))
                .lineSpacing(2)
                .foregroundStyle(AppTheme.ColorToken.accentInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A hairline between a choice's header and its fields.
struct ChoiceDivider: View {
    var body: some View {
        Rectangle().fill(AppTheme.ColorToken.separator).frame(height: 0.5)
    }
}
