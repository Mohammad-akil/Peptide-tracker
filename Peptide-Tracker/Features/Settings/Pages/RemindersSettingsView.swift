import SwiftUI

/// Refill reminders: notifications on or off, and the defaults new
/// medicines start from — what time, how many days ahead, and whether to
/// keep reminding until it's refilled.
struct RemindersSettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var showsNotificationsDenied = false
    /// iOS-level permission, which can be switched off outside the app.
    @State private var systemDenied = false

    private static let headsUpChoices = [1, 2, 3, 5, 7, 10, 14]

    var body: some View {
        @Bindable var store = store

        SettingsPageScaffold(page: .reminders) {
            GroupedSection(footer: notificationsFooter) {
                ControlRow(symbol: "bell.badge.fill", tint: Color(hex: 0xFF453A), title: "Notifications", showsDivider: false) {
                    Toggle("Notifications", isOn: notificationsBinding)
                        .labelsHidden()
                        .tint(AppTheme.ColorToken.accent)
                }
            }

            GroupedSection(
                title: "For new medicines",
                footer: "Each medicine can have its own reminder. Change it from the medicine’s page."
            ) {
                ControlRow(symbol: "clock.fill", tint: Color(hex: 0x30B0C7), title: "Reminder time") {
                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: { store.settings.defaultReminderTime.on(.now) },
                            set: { store.settings.defaultReminderTime = TimeOfDay(date: $0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "en_GB"))
                }
                ControlRow(symbol: "calendar", tint: Color(hex: 0x0A84FF), title: "Heads-up", showsDivider: false) {
                    Menu {
                        Picker("Heads-up", selection: $store.settings.defaultDaysBefore) {
                            ForEach(Self.headsUpChoices, id: \.self) { days in
                                Text(Self.daysBefore(days)).tag(days)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(Self.daysBefore(store.settings.defaultDaysBefore))
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold))
                        }
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    }
                }
            }

            GroupedSection(footer: "If you haven’t marked a medicine as ordered or refilled, we remind you again each morning.") {
                ControlRow(symbol: "arrow.clockwise", tint: Color(hex: 0xFF9F0A), title: "Remind again", showsDivider: false) {
                    Toggle("Remind again until refilled", isOn: $store.settings.remindAgainUntilRefilled)
                        .labelsHidden()
                        .tint(AppTheme.ColorToken.accent)
                }
            }
        }
        .task {
            systemDenied = await store.scheduler.authorizationStatus() == .denied
        }
        .alert("Notifications are off", isPresented: $showsNotificationsDenied) {
            Button("Not now", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } message: {
            Text("Turn on notifications for this app in Settings to get refill reminders.")
        }
    }

    /// "5 days before", "1 day before"
    static func daysBefore(_ days: Int) -> String {
        "\(days) \(days == 1 ? "day" : "days") before"
    }

    private var notificationsFooter: String {
        if systemDenied { return "Notifications are off for this app in iOS Settings, so reminders can’t arrive." }
        return store.settings.notificationsEnabled
            ? "We send one heads-up before each medicine runs out."
            : "Turn on to get a heads-up before a medicine runs out."
    }

    /// On asks iOS first; if the user said no before, it points to Settings.
    private var notificationsBinding: Binding<Bool> {
        Binding {
            store.settings.notificationsEnabled && !systemDenied
        } set: { isOn in
            guard isOn else {
                store.settings.notificationsEnabled = false
                return
            }
            Task {
                switch await store.scheduler.authorizationStatus() {
                case .notDetermined:
                    store.settings.notificationsEnabled = await store.scheduler.requestAuthorization()
                case .denied:
                    showsNotificationsDenied = true
                default:
                    store.settings.notificationsEnabled = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack { RemindersSettingsView() }
        .environment(MedicineStore.preview())
}
