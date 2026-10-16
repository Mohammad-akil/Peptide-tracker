import SwiftUI

// MARK: - Q5 Pharmacy

struct PharmacyQuestion: View {
    @Binding var answers: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "Question 5 of 5",
                title: "Where do you get your refills?",
                reason: "Optional. With a pharmacy saved, reminders get a Call pharmacy button."
            )
            VStack(spacing: 10) {
                OnboardingChoice(
                    icon: .store,
                    title: "One pharmacy I go to",
                    subtitle: "Add it to every reminder",
                    isSelected: answers.pharmacyKind == .one,
                    action: { answers.pharmacyKind = .one }
                ) {
                    if answers.pharmacyKind == .one {
                        ChoiceDivider()
                        OnboardingField(label: "Pharmacy name", placeholder: "e.g. the one on your street", text: $answers.pharmacyName)
                            .textContentType(.organizationName)
                        OnboardingField(label: "Phone (optional)", placeholder: "For the Call pharmacy button", text: $answers.pharmacyPhone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                }
                OnboardingChoice(
                    icon: .truck,
                    title: "Delivery or online pharmacy",
                    subtitle: "Reminders come early enough for shipping",
                    isSelected: answers.pharmacyKind == .delivery,
                    action: { answers.pharmacyKind = .delivery }
                )
                OnboardingChoice(
                    icon: .sliders,
                    title: "It varies",
                    subtitle: "No pharmacy on reminders",
                    isSelected: answers.pharmacyKind == .varies,
                    action: { answers.pharmacyKind = .varies }
                )
            }
        }
    }
}
