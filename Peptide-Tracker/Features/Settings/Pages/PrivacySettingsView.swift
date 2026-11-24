import SwiftUI

/// Settings → Privacy: App Lock, names on the lock screen and widgets, and
/// a quieter app icon — for anyone who'd rather nobody glancing at their
/// phone sees what they take.
struct PrivacySettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showsIconPicker = false

    var body: some View {
        @Bindable var store = store

        SettingsPageScaffold(page: .privacy) {
            GroupedSection(footer: lockFooter) {
                ControlRow(symbol: AppLock.methodSymbol, tint: Color(hex: 0x30D158), title: String(localized: "App Lock"), showsDivider: false) {
                    Toggle("App Lock", isOn: Binding(
                        get: { store.settings.appLock },
                        set: { setAppLock($0) }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.ColorToken.accent)
                    .disabled(!AppLock.isAvailable && !store.settings.appLock)
                }
            }

            GroupedSection(footer: store.settings.showsMedicineName
                ? String(localized: "Reminders and widgets show each medicine’s name, even on the Lock Screen.")
                : String(localized: "Reminders say “A medicine runs out in 3 days” and widgets show the type (“Injection”) instead of the name.")
            ) {
                ControlRow(symbol: "eye.slash.fill", tint: Color(hex: 0x5E5CE6), title: String(localized: "Hide medicine names"), showsDivider: false) {
                    Toggle("Hide medicine names", isOn: Binding(
                        get: { !store.settings.showsMedicineName },
                        set: { hidden in withAnimation(.snappy) { store.settings.showsMedicineName = !hidden } }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.ColorToken.accent)
                }
            }

            GroupedSection(footer: String(localized: "Pick a plainer icon, like Graphite or Mono, so the Home Screen gives less away.")) {
                SettingsSheetRow(title: String(localized: "App icon"), value: AppIconOption.current.title, showsDivider: false, action: { showsIconPicker = true }) {
                    AppIconOption.current.preview
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 7, style: .continuous))
                }
            }
        }
        .sheet(isPresented: $showsIconPicker) { AppIconPicker() }
    }

    private var lockFooter: String {
        guard AppLock.isAvailable || store.settings.appLock else {
            return String(localized: "Set a passcode in the iPhone’s Settings to use App Lock.")
        }
        return String(localized: "Asks for \(AppLock.methodName) when \(Bundle.main.appName) opens, and hides it in the app switcher.")
    }

    /// Turning the lock on or off needs the owner, so it asks first.
    private func setAppLock(_ isOn: Bool) {
        Task {
            let reason = isOn ? String(localized: "Turn on App Lock for \(Bundle.main.appName).") : String(localized: "Turn off App Lock for \(Bundle.main.appName).")
            guard await AppLock.shared.authenticate(reason: reason) else { return }
            withAnimation(.snappy) { store.settings.appLock = isOn }
            if !isOn { AppLock.shared.disable() }
            router.showToast(isOn ? String(localized: "App Lock on") : String(localized: "App Lock off"))
        }
    }
}
