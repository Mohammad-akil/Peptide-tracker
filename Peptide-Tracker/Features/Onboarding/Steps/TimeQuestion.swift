import SwiftUI

// MARK: - Q4 Reminder time

struct TimeQuestion: View {
    @Binding var answers: OnboardingAnswers
    @State private var picksCustomTime = false

    private let presets: [(TimeOfDay, String)] = [
        (TimeOfDay(hour: 9, minute: 0), "Morning"),
        (TimeOfDay(hour: 13, minute: 0), "Lunchtime"),
        (TimeOfDay(hour: 18, minute: 0), "After work"),
        (TimeOfDay(hour: 20, minute: 0), "Evening"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeader(
                title: "When should refill reminders arrive?",
                reason: "Pick a time you can act on, like before you pass the pharmacy."
            )
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(presets, id: \.0) { time, name in
                    preset(time, name: name)
                }
            }

            Button { picksCustomTime = true } label: {
                Label {
                    Text(isCustom ? "Another time · \(answers.reminderTime.label)" : "Choose another time")
                } icon: {
                    FilledIcon(.clock, size: 18)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.vertical, -11)

            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .padding(.leading, 4)
                HStack(alignment: .top, spacing: 12) {
                    FilledIcon(.pill, size: 20)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Metformin runs out in 5 days").font(.system(size: 15, weight: .semibold))
                            Spacer(minLength: 8)
                            Text(answers.reminderTime.label)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                                .contentTransition(.numericText())
                        }
                        Text("Tap to refill.").font(.system(size: 15))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
                .shadow(color: Color(hex: 0x28185A, opacity: 0.08), radius: 12, y: 8)
                .accessibilityElement(children: .combine)
            }
        }
        .sheet(isPresented: $picksCustomTime) {
            ReminderTimePicker(time: $answers.reminderTime)
        }
    }

    private var isCustom: Bool { !presets.contains { $0.0 == answers.reminderTime } }

    private func preset(_ time: TimeOfDay, name: String) -> some View {
        let isSelected = answers.reminderTime == time
        return Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { answers.reminderTime = time }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(time.label)
                    .font(.system(size: 24, weight: .bold))
                    .kerning(-0.4)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 82)
            .background(
                isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground,
                in: .rect(cornerRadius: 20, style: .continuous)
            )
            .selectionBorder(isSelected, cornerRadius: 20)
            .overlay(alignment: .topTrailing) {
                RadioMark(isSelected: isSelected, size: 22)
                    .opacity(isSelected ? 1 : 0)
                    .padding(12)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(time.label), \(name)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct ReminderTimePicker: View {
    @Binding var time: TimeOfDay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Reminder time",
                selection: Binding(get: { time.on(.now) }, set: { time = TimeOfDay(date: $0) }),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "en_GB"))
            .navigationTitle("Reminder time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}
