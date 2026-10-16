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
                row(.user, "Tracking for", trackingValue, step: .who)
                row(.bell, "Heads-up", "\(answers.leadTime.daysBefore) days before", step: .refill)
                row(.clock, "Reminder time", answers.reminderTime.label, step: .time)
                row(.check, "Dose reminders", answers.tracksDoses ? "On" : "Off", step: .doses)
                row(.store, "Pharmacy", pharmacyValue, step: .pharmacy, showsDivider: false)
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

    private func row(_ icon: AppIcon, _ title: String, _ value: String, step: OnboardingStep, showsDivider: Bool = true) -> some View {
        Button { onEdit(step) } label: {
            HStack(spacing: 12) {
                FilledIcon(icon, size: 18)
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 10, style: .continuous))
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
