import SwiftUI

// MARK: - What's driving you

struct ReasonQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "I want to do this because…",
                title: "What’s driving you to reach your goal?",
                reason: "Choose all that apply. We’ll remind you of your why when you need it most."
            )
            VStack(spacing: 10) {
                ForEach(Array(GoalReason.allCases.enumerated()), id: \.element) { index, option in
                    choice(option).stagger(index)
                }
            }
        }
    }

    private func choice(_ option: GoalReason) -> some View {
        let isSelected = answers.reasons.contains(option)
        return OnboardingMultiChoice(
            symbol: option.symbol,
            title: option.title,
            isSelected: isSelected,
            action: {
                if isSelected { answers.reasons.remove(option) } else { answers.reasons.insert(option) }
            }
        ) {
            if isSelected && option == .other {
                ChoiceDivider()
                OnboardingField(label: "Your reason", placeholder: "e.g. Keep up with my kids", text: $answers.otherReason)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }
}
