import SwiftUI

/// Settings → iCloud sync: backup and sync through the user's own iCloud,
/// off until they agree in the iCloud popup. Shows when it last synced,
/// and syncs on demand.
struct ICloudSettingsView: View {
    private var sync: CloudSync { .shared }
    /// Switching it on asks first, with the same popup as after setup.
    @State private var asksForConsent = false

    var body: some View {
        SettingsPageScaffold(page: .icloud) {
            GroupedSection(footer: String(localized: "Your medicines, doses, weights and check-ins are backed up to your private iCloud and kept in step on every iPhone and iPad signed in to it. Nobody else, including us, can see them.")) {
                ControlRow(symbol: "icloud.fill", tint: Color(hex: 0x32ADE6), title: String(localized: "iCloud sync"), showsDivider: false) {
                    Toggle("iCloud sync", isOn: Binding(
                        get: { sync.isEnabled },
                        set: { enabled in
                            if enabled {
                                asksForConsent = true
                            } else {
                                withAnimation(.snappy) { sync.isEnabled = false }
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.ColorToken.accent)
                }
            }

            if sync.isEnabled {
                GroupedSection(footer: String(localized: "It syncs a few seconds after each change you make, and you can sync any time here.")) {
                    SettingsRowLabel(symbol: statusSymbol, tint: statusTint, title: String(localized: "Status"), value: sync.detail)
                        .rowDivider(true, inset: 58)
                        .contentTransition(.opacity)
                    Button {
                        HapticFeedback.selection()
                        Task { await sync.syncNow() }
                    } label: {
                        SettingsRowLabel(symbol: "arrow.triangle.2.circlepath", tint: Color(hex: 0x30D158), title: String(localized: "Sync now"))
                    }
                    .buttonStyle(RowPressStyle())
                    .disabled(sync.status == .syncing)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: sync.status)
        .animation(.snappy, value: sync.isEnabled)
        .iCloudConsentPopup(isPresented: $asksForConsent)
    }

    private var statusSymbol: String {
        switch sync.status {
        case .synced, .idle: "checkmark.icloud.fill"
        case .syncing: "arrow.triangle.2.circlepath.icloud.fill"
        case .noAccount, .failed: "exclamationmark.icloud.fill"
        case .off: "icloud.slash.fill"
        }
    }

    private var statusTint: Color {
        switch sync.status {
        case .synced, .idle: Color(hex: 0x30D158)
        case .syncing: Color(hex: 0x32ADE6)
        case .noAccount, .failed: Color(hex: 0xFF9F0A)
        case .off: Color(hex: 0x8E8E93)
        }
    }
}

#Preview {
    NavigationStack { ICloudSettingsView() }
        .environment(MedicineStore.preview())
        .environment(AppRouter())
}
