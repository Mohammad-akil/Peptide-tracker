import SwiftUI

// MARK: - Q2 Refill lead time

struct RefillQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Question 2 of 5",
                title: "How long does a refill usually take you?",
                reason: "From the moment you order to having it in your hand. This sets how early we remind you."
            )
            VStack(spacing: 10) {
                choice(.sameDay, icon: .zap, title: "Same day", subtitle: "I pick it up whenever I need it")
                choice(.oneToTwoDays, icon: .store, title: "1 to 2 days", subtitle: "The pharmacy orders it in")
                choice(.threeToFiveDays, icon: .truck, title: "3 to 5 days", subtitle: "It comes by delivery or post")
                choice(.weekOrMore, icon: .steth, title: "A week or more", subtitle: "My doctor has to renew the prescription")
            }
        }
    }

    private func choice(_ option: RefillLeadTime, icon: AppIcon, title: String, subtitle: String) -> some View {
        OnboardingChoice(
            icon: icon,
            title: title,
            subtitle: subtitle,
            isSelected: answers.leadTime == option,
            action: { answers.leadTime = option }
        )
    }
}
