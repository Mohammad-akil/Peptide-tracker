import SwiftUI

// MARK: - Q2b What this means

struct BenefitStep: View {
    let answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingHeader(eyebrow: "What this means for you", title: "No more running out between packs.")
            BenefitChart(daysBefore: answers.leadTime.daysBefore)
            VStack(alignment: .leading, spacing: 12) {
                point(.bell, "A reminder \(answers.leadTime.daysBefore) days before each run-out")
                point(.store, "Time to order and pick up, without rushing")
                point(.check, "No gaps between packs")
            }
            Text("Example for one medicine taken twice a day from 60-pill packs. Your dates depend on what you add.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func point(_ icon: AppIcon, _ text: String) -> some View {
        HStack(spacing: 12) {
            FilledIcon(icon, size: 17)
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 10, style: .continuous))
            Text(text).font(.system(size: 16, weight: .medium))
        }
        .accessibilityElement(children: .combine)
    }
}
