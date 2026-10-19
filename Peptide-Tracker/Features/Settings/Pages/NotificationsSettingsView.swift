import SwiftUI

/// How reminders read and when the extras come: the wording (with a live
/// preview), whether names show on the lock screen, how long snooze waits,
/// the morning and bedtime nudges, and a way to re-plan every reminder.
struct NotificationsSettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var isRefreshing = false

    var body: some View {
        @Bindable var store = store

        SettingsPageScaffold(page: .notifications) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Preview")
                ReminderBannerPreview(title: previewTitle, message: previewMessage)
            }

            GroupedSection(
                title: "Message",
                footer: "Write {medicine} where the medicine’s name should go. Leave it empty for “Tap to refill.”"
            ) {
                TextField("Tap to refill.", text: $store.settings.reminderMessage, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(1...3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .rowDivider(true)
                SuggestionChips(
                    options: ["Time to order {medicine}.", "Call the pharmacy today.", "Don’t forget your refill!"],
                    selection: $store.settings.reminderMessage
                )
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupedSection(footer: store.settings.showsMedicineName
                ? "Reminders name the medicine, even on the lock screen."
                : "Reminders say “A medicine runs out in 3 days”, so nobody glancing at your phone sees what you take."
            ) {
                ControlRow(symbol: "eye.fill", tint: Color(hex: 0x5E5CE6), title: "Show medicine name", showsDivider: false) {
                    Toggle("Show medicine name", isOn: $store.settings.showsMedicineName.animation(.snappy))
                        .labelsHidden()
                        .tint(AppTheme.ColorToken.accent)
                }
            }

            GroupedSection(title: "Snooze", footer: "How long “\(store.settings.snooze.actionTitle)” on a reminder waits.") {
                ForEach(Array(SnoozeOption.allCases.enumerated()), id: \.element) { index, option in
                    CheckRow(
                        title: option.title,
                        isSelected: store.settings.snooze == option,
                        showsDivider: index < SnoozeOption.allCases.count - 1
                    ) { store.settings.snooze = option }
                }
            }

            GroupedSection(title: "Daily reminders", footer: "A nudge each day to check your doses, on top of refill reminders.") {
                dailyRow(
                    title: "Morning",
                    symbol: "sun.max.fill",
                    tint: Color(hex: 0xFF9F0A),
                    isOn: $store.settings.morningReminder,
                    time: $store.settings.morningTime,
                    showsDivider: true
                )
                dailyRow(
                    title: "Before bed",
                    symbol: "moon.fill",
                    tint: Color(hex: 0x5E5CE6),
                    isOn: $store.settings.sleepReminder,
                    time: $store.settings.sleepTime,
                    showsDivider: false
                )
            }

            GroupedSection {
                SettingsRowLabel(symbol: "speaker.wave.2.fill", tint: Color(hex: 0xFF375F), title: "Sound", value: "Coming soon", valueTint: AppTheme.ColorToken.tertiaryText)
            }

            GroupedSection(footer: "Plans every reminder again from scratch. Handy after travelling or changing the time.") {
                Button(action: refresh) {
                    HStack(spacing: 14) {
                        SettingsTile(symbol: "arrow.triangle.2.circlepath", tint: Color(hex: 0x30B0C7))
                        Text("Refresh reminder times")
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.ColorToken.accent)
                        Spacer(minLength: 8)
                        if isRefreshing { ProgressView() }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .contentShape(.rect)
                }
                .buttonStyle(RowPressStyle())
                .disabled(isRefreshing)
            }
        }
    }

    /// A daily nudge: its switch, and its time once on.
    @ViewBuilder
    private func dailyRow(title: String, symbol: String, tint: Color, isOn: Binding<Bool>, time: Binding<TimeOfDay>, showsDivider: Bool) -> some View {
        ControlRow(symbol: symbol, tint: tint, title: title, showsDivider: showsDivider || isOn.wrappedValue) {
            Toggle(title, isOn: isOn.animation(.snappy))
                .labelsHidden()
                .tint(AppTheme.ColorToken.accent)
        }
        if isOn.wrappedValue {
            ControlRow(symbol: "clock.fill", tint: Color(hex: 0x30B0C7), title: "Time", showsDivider: showsDivider) {
                DatePicker(
                    "\(title) time",
                    selection: Binding(get: { time.wrappedValue.on(.now) }, set: { time.wrappedValue = TimeOfDay(date: $0) }),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_GB"))
            }
            .transition(.opacity)
        }
    }

    // MARK: Preview

    /// The medicine running out soonest, or a stand-in before any are added.
    private var previewMedicine: Medicine {
        store.medicinesByUrgency.first ?? Medicine(
            name: "Metformin", strength: "", type: .tablet, color: .blue,
            stock: 15, capacity: 60, perDay: 3, intakeTimes: [.morning],
            reminderDaysBefore: 5, reminderTime: .defaultReminder
        )
    }

    private var previewTitle: String {
        let medicine = previewMedicine
        return ReminderScheduler.refillTitle(for: medicine, settings: store.settings, at: medicine.reminderDate())
    }

    private var previewMessage: String {
        store.settings.notificationMessage(for: previewMedicine)
    }

    private func refresh() {
        isRefreshing = true
        Task {
            await store.refreshReminders()
            isRefreshing = false
            router.showToast("Reminder times refreshed")
        }
    }
}

/// A lock-screen style banner showing how a reminder will read.
private struct ReminderBannerPreview: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(AppTheme.ColorToken.accent.gradient, in: .rect(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text("now")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                }
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
        .contentTransition(.opacity)
        .animation(.snappy, value: title + message)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(title). \(message)")
    }
}

#Preview {
    NavigationStack { NotificationsSettingsView() }
        .environment(MedicineStore.preview())
        .environment(AppRouter())
}
