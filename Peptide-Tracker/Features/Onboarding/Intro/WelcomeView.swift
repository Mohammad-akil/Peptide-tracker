import SwiftUI

/// Onboarding's second screen: what the app does in one line, three
/// reassurances, then the five setup questions. Everything arrives one item
/// at a time, top to bottom.
struct WelcomeView: View {
    let onContinue: () -> Void

    @State private var appears = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeIllustration(appears: appears)
                .padding(.top, 30)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 0) {
                Text("Never run out of your medicines.")
                    .font(.system(size: 34, weight: .heavy))
                    .kerning(-0.8)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                    .staggeredAppear(appears, order: 2)
                Text("Tell us what you have and how much you take. We’ll remind you early enough to refill.")
                    .font(.system(size: 17))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .staggeredAppear(appears, order: 3)

                VStack(alignment: .leading, spacing: 12) {
                    point("No account needed", order: 4)
                    point("Pills, injections, creams, liquids and drops", order: 5)
                    point("Your data stays on your phone", order: 6)
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
            .staggeredAppear(appears, order: 7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .onAppear { appears = true }
    }

    private func point(_ text: String, order: Int) -> some View {
        HStack(spacing: 12) {
            FilledIcon(.check, size: 20)
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 20)
            Text(text).font(.system(size: 16))
        }
        .accessibilityElement(children: .combine)
        .staggeredAppear(appears, order: order)
    }
}

/// Two medicines counting down with a reminder arriving over them — a
/// picture of what the app does, built from the real components.
private struct WelcomeIllustration: View {
    let appears: Bool

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
            .staggeredAppear(appears, order: 0)

            NotificationPreview(title: "Metformin runs out in 5 days", time: "9:00")
                .rotationEffect(.degrees(-1.5))
                .padding(.horizontal, 6)
                .padding(.top, 170)
                // Drops onto the card like a real banner arriving.
                .staggeredAppear(appears, order: 1, from: -24)
        }
        .frame(height: 250, alignment: .top)
        .accessibilityHidden(true)
    }
}

// MARK: - Staggered entrance

private extension View {
    /// Fades and slides into place, `order` steps after the screen appears.
    /// Reduce Motion shows everything at once, without movement.
    func staggeredAppear(_ appears: Bool, order: Int, from offset: CGFloat = 18) -> some View {
        modifier(StaggeredAppear(appears: appears, order: order, offset: offset))
    }
}

private struct StaggeredAppear: ViewModifier {
    let appears: Bool
    let order: Int
    let offset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appears ? 1 : 0)
            .offset(y: appears || reduceMotion ? 0 : offset)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(response: 0.55, dampingFraction: 0.82).delay(0.15 + Double(order) * 0.1),
                value: appears
            )
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
