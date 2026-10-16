import SwiftUI

/// Onboarding's second screen: what the app does in one line, three
/// reassurances, then the five setup questions.
struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeIllustration()
                .padding(.top, 30)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 0) {
                Text("Never run out of your medicines.")
                    .font(.system(size: 34, weight: .heavy))
                    .kerning(-0.8)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tell us what you have and how much you take. We’ll remind you early enough to refill.")
                    .font(.system(size: 17))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 12) {
                    point("No account needed")
                    point("Pills, injections, creams, liquids and drops")
                    point("Your data stays on your phone")
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)

            Spacer(minLength: 16)

            VStack(spacing: 8) {
                Button("Get started", action: onContinue)
                    .buttonStyle(.glassPrimary)
                Text("5 quick questions, about a minute")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
    }

    private func point(_ text: String) -> some View {
        HStack(spacing: 12) {
            Icon(.check, size: 20)
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 20)
            Text(text).font(.system(size: 16))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Two medicines counting down with a reminder arriving over them — a
/// picture of what the app does, built from the real components.
private struct WelcomeIllustration: View {
    private let medicines = [
        Medicine(name: "Vitamin D3", strength: "1000 IU", type: .capsule, color: .pink,
                 stock: 14, capacity: 60, perDay: 2, intakeTimes: [.morning],
                 reminderDaysBefore: 5, reminderTime: .defaultReminder),
        Medicine(name: "Metformin", strength: "500 mg", type: .capsule, color: .blue,
                 stock: 26, capacity: 60, perDay: 2, intakeTimes: [.morning],
                 reminderDaysBefore: 5, reminderTime: .defaultReminder),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(Array(medicines.enumerated()), id: \.element.id) { index, medicine in
                    MedicineRow(medicine: medicine, now: .now, showsDivider: index == 0)
                }
            }
            .groupedCard()
            .shadow(color: Color(hex: 0x28185A, opacity: 0.12), radius: 25, y: 18)
            .padding(.horizontal, 10)
            .padding(.top, 20)

            NotificationPreview(title: "Metformin runs out in 5 days", time: "9:00")
                .rotationEffect(.degrees(-1.5))
                .padding(.horizontal, 6)
                .padding(.top, 170)
        }
        .frame(height: 250, alignment: .top)
        .accessibilityHidden(true)
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
