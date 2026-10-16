import SwiftUI

// MARK: - Q1 Who

struct WhoQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Question 1 of 5",
                title: "Who are you tracking medicines for?",
                reason: "So reminders use the right name. You can add more people later."
            )
            VStack(spacing: 10) {
                choice(.me, icon: .user, subtitle: "Track my own medicines")
                choice(.someoneElse, icon: .heart, subtitle: "A parent, child or partner")
                choice(.both, icon: .users, subtitle: "Keep a separate list for each person")
            }
        }
    }

    private func choice(_ option: TrackingFor, icon: AppIcon, subtitle: String) -> some View {
        let isSelected = answers.trackingFor == option
        return OnboardingChoice(
            icon: icon,
            title: option.title,
            subtitle: subtitle,
            isSelected: isSelected,
            action: { answers.trackingFor = option }
        ) {
            if isSelected && option == .someoneElse {
                ChoiceDivider()
                OnboardingField(label: "Their name", placeholder: "e.g. Mum", text: $answers.personName)
                    .textContentType(.givenName)
                Text("Reminders will say “\(answers.personName.isEmpty ? "Mum" : answers.personName)’s Metformin runs out in 5 days”.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
        }
    }
}
