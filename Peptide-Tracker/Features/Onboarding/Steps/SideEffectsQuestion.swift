import SwiftUI

// MARK: - Side-effect concerns

struct SideEffectsQuestion: View {
    @Binding var answers: OnboardingAnswers

    private var options: [SideEffectConcern] {
        SideEffectConcern.allCases.filter { $0 != .injectionAnxiety || answers.route != .pill }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: String(localized: "Which side effects are you most concerned about?"),
                reason: String(localized: "If any, let us know so we can customize your experience. Choose all that apply.")
            )
            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    choice(option).stagger(index)
                }
            }
        }
    }

    private func choice(_ option: SideEffectConcern) -> some View {
        let isSelected = answers.concerns.contains(option)
        return OnboardingMultiChoice(
            symbol: option.symbol,
            title: option.title,
            subtitle: option.subtitle,
            isSelected: isSelected,
            action: { toggle(option) }
        ) {
            if isSelected && option == .other {
                ChoiceDivider()
                OnboardingField(label: String(localized: "Your concern"), placeholder: String(localized: "e.g. Fatigue"), text: $answers.otherConcern)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }

    private func toggle(_ option: SideEffectConcern) {
        if answers.concerns.contains(option) {
            answers.concerns.remove(option)
        } else if option == .notConcerned {
            answers.concerns = [.notConcerned]
        } else {
            answers.concerns.remove(.notConcerned)
            answers.concerns.insert(option)
        }
    }
}
