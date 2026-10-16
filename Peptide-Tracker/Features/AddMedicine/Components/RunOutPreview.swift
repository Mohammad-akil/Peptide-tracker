import SwiftUI

/// "You'll run out on 14 Oct. We'll remind you on 9 Oct at 9:00." with a
/// little Today → Reminder → Out track.
struct RunOutPreview: View {
    let draft: MedicineDraft
    let showsErrors: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            message
                .font(.system(size: 15))
                .lineSpacing(2)
            if let medicine = draft.previewMedicine(), medicine.stock > 0 {
                track(for: medicine)
            }
        }
        .foregroundStyle(AppTheme.ColorToken.accentInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 20, style: .continuous))
        .animation(.snappy, value: draft.stock)
        .animation(.snappy, value: draft.perDay)
        .accessibilityElement(children: .combine)
    }

    private var message: Text {
        guard let medicine = draft.previewMedicine() else {
            return Text(showsErrors && draft.perDayError != nil
                        ? "Fix the daily amount to see your run-out date."
                        : "Add how much you have and your daily amount to see when you’ll run out.")
        }
        guard medicine.stock > 0 else {
            return Text("Add how many \(medicine.unit.plural) you have to see when you’ll run out.")
        }
        let runOut = medicine.runOutDate()
        let reminder = medicine.reminderDate()
        if reminder <= .now {
            return Text("You’ll run out on ") + Text(runOut.dayMonth).bold()
                + Text(". That’s inside your heads-up window, so it’s time to refill.")
        }
        return Text("You’ll run out on ") + Text(runOut.dayMonth).bold()
            + Text(". We’ll remind you on ") + Text("\(reminder.dayMonth) at \(medicine.reminderTime.label)").bold() + Text(".")
    }

    private func track(for medicine: Medicine) -> some View {
        let total = max(medicine.daysLeft, 1)
        let reminderOffset = Calendar.current.days(from: .now, to: medicine.reminderDate())
        let fraction = min(max(Double(reminderOffset) / Double(total), 0), 1)

        return GeometryReader { proxy in
            let width = proxy.size.width - 12
            ZStack(alignment: .topLeading) {
                Capsule().fill(AppTheme.ColorToken.accent.opacity(0.25)).frame(height: 4).offset(x: 6, y: 6).frame(width: width)
                Capsule().fill(AppTheme.ColorToken.accent).frame(width: width * fraction, height: 4).offset(x: 6, y: 6)
                Circle().fill(AppTheme.ColorToken.accent).frame(width: 12, height: 12).offset(y: 2)
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(AppTheme.ColorToken.accent, lineWidth: 3))
                    .frame(width: 16, height: 16)
                    .offset(x: 6 + width * fraction - 8)
                Circle().fill(AppTheme.ColorToken.destructive).frame(width: 12, height: 12).offset(x: width, y: 2)

                Text("Today").offset(y: 20)
                Text("Reminder \(medicine.reminderDate().dayMonth)")
                    .fixedSize()
                    .frame(width: 0)
                    .offset(x: 6 + width * fraction, y: 20)
                    .opacity(fraction > 0.18 && fraction < 0.82 ? 1 : 0)
                Text("Out \(medicine.runOutDate().dayMonth)")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: 20)
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .frame(height: 36)
    }
}
