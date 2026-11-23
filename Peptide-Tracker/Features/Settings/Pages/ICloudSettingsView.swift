import SwiftUI

/// Settings → iCloud sync: backup and sync through the user's own iCloud,
/// on by default. Shows when it last synced, and syncs on demand.
struct ICloudSettingsView: View {
    private var sync: CloudSync { .shared }

    var body: some View {
        SettingsPageScaffold(page: .icloud) {
            GroupedSection(footer: "Your medicines, doses, weights and check-ins are backed up to your private iCloud and kept in step on every iPhone and iPad signed in to it. Nobody else, including us, can see them.") {
                ControlRow(symbol: "icloud.fill", tint: Color(hex: 0x32ADE6), title: "iCloud sync", showsDivider: false) {
                    Toggle("iCloud sync", isOn: Binding(
                        get: { sync.isEnabled },
                        set: { enabled in withAnimation(.snappy) { sync.isEnabled = enabled } }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.ColorToken.accent)
                }
            }

            if sync.isEnabled {
                GroupedSection(footer: "It syncs a few seconds after each change you make, and you can sync any time here.") {
                    SettingsRowLabel(symbol: statusSymbol, tint: statusTint, title: "Status", value: sync.detail)
                        .rowDivider(true, inset: 58)
                        .contentTransition(.opacity)
                    Button {
                        HapticFeedback.selection()
                        Task { await sync.syncNow() }
                    } label: {
                        SettingsRowLabel(symbol: "arrow.triangle.2.circlepath", tint: Color(hex: 0x30D158), title: "Sync now")
                    }
                    .buttonStyle(RowPressStyle())
                    .disabled(sync.status == .syncing)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: sync.status)
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
