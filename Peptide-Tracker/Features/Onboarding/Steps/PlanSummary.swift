import SwiftUI

// MARK: - You're set up

struct PlanSummary: View {
    let answers: OnboardingAnswers
    let onEdit: (OnboardingStep) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                eyebrow: "All done",
                title: "You’re set up.",
                reason: "Here’s how reminders will work. Tap a line to change it."
            )
            VStack(spacing: 0) {
                row(.user, Color(hex: 0x0A84FF), "Tracking for", trackingValue, step: .who)
                row(.bell, Color(hex: 0xFF453A), "Heads-up", "\(answers.leadTime.daysBefore) days before", step: .refill)
                row(.clock, Color(hex: 0x30B0C7), "Reminder time", answers.reminderTime.label, step: .time)
                row(.check, AppTheme.ColorToken.accent, "Dose reminders", answers.tracksDoses ? "On" : "Off", step: .doses)
                row(.store, Color(hex: 0xFF9F0A), "Pharmacy", pharmacyValue, step: .pharmacy, showsDivider: false)
            }
            .groupedCard()
        }
    }

    private var trackingValue: String {
        let name = answers.personName.trimmingCharacters(in: .whitespaces)
        return answers.trackingFor == .someoneElse && !name.isEmpty ? name : answers.trackingFor.title
    }

    private var pharmacyValue: String {
        let name = answers.pharmacyName.trimmingCharacters(in: .whitespaces)
        return answers.pharmacyKind == .one && !name.isEmpty ? name : answers.pharmacyKind.title
    }

    /// Each row's own colour behind a white icon, the same in light and dark
    /// mode, like iOS Settings.
    private func row(_ icon: AppIcon, _ tint: Color, _ title: String, _ value: String, step: OnboardingStep, showsDivider: Bool = true) -> some View {
        Button { onEdit(step) } label: {
            HStack(spacing: 12) {
                FilledIcon(icon, size: 18)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(tint, in: .rect(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .lineLimit(1)
                Chevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .rowDivider(showsDivider, inset: 62)
        }
        .buttonStyle(RowPressStyle())
    }
}
