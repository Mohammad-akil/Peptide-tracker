import SwiftUI

// MARK: - Q3 Doses

struct DosesQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "Do you want dose reminders too?",
                reason: "Refill reminders are always on. Dose reminders are optional."
            )
            VStack(spacing: 12) {
                OnboardingChoice(
                    icon: .check,
                    title: "Remind me to take doses",
                    subtitle: "Tick off each dose and your count stays exact.",
                    isSelected: answers.tracksDoses,
                    action: { answers.tracksDoses = true }
                ) {
                    example {
                        (Text("Metformin ").fontWeight(.semibold) + Text("· 20:00").foregroundStyle(AppTheme.ColorToken.secondaryText))
                        Spacer(minLength: 0)
                        Circle()
                            .strokeBorder(Color(light: 0xCBC6D9, dark: 0x4C4858), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
                OnboardingChoice(
                    icon: .pill,
                    title: "Just track my supply",
                    subtitle: "We count down from your schedule. One reminder before you run out.",
                    isSelected: !answers.tracksDoses,
                    action: { answers.tracksDoses = false }
                ) {
                    example {
                        Text("Metformin").fontWeight(.semibold)
                        Spacer(minLength: 0)
                        Text("13 days left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Urgency.healthy.ink)
                    }
                }
            }
        }
    }

    /// A small preview row of what the choice looks like on Today.
    private func example<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            MedicineIconView(type: .capsule, color: .blue, size: 30)
            content()
        }
        .font(.system(size: 15))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.ColorToken.background, in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }
}
