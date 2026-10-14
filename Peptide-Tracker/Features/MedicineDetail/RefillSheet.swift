import SwiftUI

/// "How many pills did you add?" — a big stepper, common pack sizes, and
/// the new run-out and reminder dates before confirming.
struct RefillSheet: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    let medicineID: UUID
    @State private var amount: Int?

    var body: some View {
        if let medicine = store.medicine(id: medicineID) {
            content(medicine, amount: amount ?? store.suggestedRefillAmount(for: medicine))
        }
    }

    private func content(_ medicine: Medicine, amount: Int) -> some View {
        var after = medicine
        after.stock += amount
        after.capacity = max(after.capacity, after.stock)
        after.orderedAt = nil
        let now = Date.now
        let reminderBefore = medicine.reminderDate(now: now)
        let step = medicine.type == .injection ? 1 : 5

        return VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How many \(medicine.unit.plural) did you add?")
                        .font(.system(size: 22, weight: .bold))
                        .kerning(-0.2)
                    Text("\(medicine.name) · \(medicine.unit.format(medicine.stock)) left")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Spacer()
                Button { dismiss() } label: {
                    Icon(.x, size: 16)
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.ColorToken.controlFill, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.top, 24)

            HStack(spacing: 18) {
                roundStepButton(.minus, label: "Remove \(step)") { self.amount = max(amount - step, step) }
                    .disabled(amount <= step)
                VStack(spacing: 4) {
                    Text("\(amount)")
                        .font(.system(size: 52, weight: .bold))
                        .kerning(-1.5)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(amount)))
                    Text("\(medicine.unit.name(for: amount)) added")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                .frame(width: 130)
                .accessibilityElement(children: .combine)
                roundStepButton(.plus, label: "Add \(step)") { self.amount = min(amount + step, 9999) }
            }
            .padding(.top, 22)
            .padding(.bottom, 16)

            Text("Common pack sizes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .padding(.bottom, 8)
            HStack(spacing: 8) {
                ForEach(medicine.type.commonPackSizes, id: \.self) { size in
                    let isSelected = size == amount
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.snappy) { self.amount = size }
                    } label: {
                        Text("+\(size)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.controlFill, in: .capsule)
                            .overlay { if isSelected { Capsule().strokeBorder(AppTheme.ColorToken.accent, lineWidth: 2) } }
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                changeRow("Runs out", from: medicine.runOutDate().dayMonth, to: after.runOutDate().dayMonth, showsDivider: true)
                changeRow(
                    "Reminder",
                    from: reminderBefore <= now || medicine.isOrdered ? "Sent" : reminderBefore.dayMonth,
                    to: after.reminderDate(now: now).dayMonth,
                    showsDivider: false
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 20, style: .continuous))
            .padding(.bottom, 16)

            Button {
                store.refill(medicineID, adding: amount)
                HapticFeedback.notification(.success)
                router.showToast("Refilled. Next reminder \(after.reminderDate(now: now).weekdayDayMonth).")
                dismiss()
            } label: {
                Text("Confirm · \(after.unit.format(after.stock))")
                    .contentTransition(.numericText(value: Double(after.stock)))
            }
            .buttonStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .animation(.snappy, value: amount)
    }

    private func roundStepButton(_ icon: AppIcon, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { action() }
        } label: {
            Icon(icon, size: 24)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: 56, height: 56)
                .background(AppTheme.ColorToken.controlFill, in: .circle)
        }
        .buttonStyle(.pressable)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }

    private func changeRow(_ title: String, from: String, to: String, showsDivider: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(AppTheme.ColorToken.secondaryText)
            Spacer()
            HStack(spacing: 8) {
                Text(from).strikethrough().foregroundStyle(AppTheme.ColorToken.secondaryText)
                Icon(.arrowR, size: 14).foregroundStyle(AppTheme.ColorToken.secondaryText)
                Text(to).bold()
            }
        }
        .font(.system(size: 15))
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            if showsDivider { Rectangle().fill(AppTheme.ColorToken.separator).frame(height: 1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) moves from \(from) to \(to)")
    }
}
