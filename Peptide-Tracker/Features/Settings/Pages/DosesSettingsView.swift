import SwiftUI

/// Dose tracking on Today: whether doses are ticked off at all, and
/// which of the four layouts Today uses, each shown as a small preview.
struct DosesSettingsView: View {
    @Environment(MedicineStore.self) private var store
    @AppStorage(DoseLayout.storageKey) private var doseLayout: DoseLayout = .list

    var body: some View {
        @Bindable var store = store

        SettingsPageScaffold(page: .doses) {
            GroupedSection(footer: store.settings.tracksDoses
                ? "Ticking off doses keeps your count exact."
                : "We count down from your schedule instead, and Today shows no doses to tick."
            ) {
                ControlRow(symbol: "checkmark.circle.fill", tint: Color(hex: 0x30D158), title: "Track doses", showsDivider: false) {
                    Toggle("Track doses", isOn: $store.settings.tracksDoses.animation(.snappy))
                        .labelsHidden()
                        .tint(AppTheme.ColorToken.accent)
                }
            }

            if store.settings.tracksDoses {
                DoseLayoutPicker(selection: $doseLayout)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    NavigationStack { DosesSettingsView() }
        .environment(MedicineStore.preview())
}
