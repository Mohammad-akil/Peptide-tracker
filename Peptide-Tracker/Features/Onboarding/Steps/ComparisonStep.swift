import SwiftUI

// MARK: - Why Doseday

/// Not a question: what the app does for them. No outcome chart (weight
/// "with vs without the app"): App Review treats that as an unsupported
/// health claim (Guideline 1.4.1).
struct ComparisonStep: View {
    let answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingHeader(
                eyebrow: String(localized: "Why Doseday"),
                title: String(localized: "Stay on track with your GLP-1."),
                reason: String(localized: "Enjoy a smoother experience, from managing side effects to hitting your weight loss milestones with less stress.")
            )
            VStack(alignment: .leading, spacing: 12) {
                point(.bell, String(localized: "Never miss a dose or a refill"), tint: Color(hex: 0xFF9F0A)).stagger(1)
                point(.heart, String(localized: "Log side effects and spot patterns"), tint: Color(hex: 0xFF3B30)).stagger(2)
                point(.timeline, String(localized: "See every milestone as you hit it"), tint: Color(hex: 0x30B07A)).stagger(3)
            }
        }
    }

    /// Each benefit its own colour tile with a white icon.
    private func point(_ icon: AppIcon, _ text: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            FilledIcon(icon, size: 17)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint, in: .rect(cornerRadius: 10, style: .continuous))
            Text(text).font(.system(size: 16, weight: .medium))
        }
        .accessibilityElement(children: .combine)
    }
}
