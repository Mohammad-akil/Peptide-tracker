import SwiftUI

/// Dose tracking on Today: whether doses are ticked off at all, which of
/// the four layouts Today uses, each shown as a small preview, and which
/// body areas injection-site rotation suggests.
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

                if store.medicines.contains(where: { $0.type == .injection }) {
                    siteRotation
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    /// The areas site rotation walks through. At least one stays on.
    private var siteRotation: some View {
        let areas = InjectionSite.Area.rotationAreas
        return GroupedSection(
            title: "Injection site rotation",
            footer: "Doseday suggests the site that has rested longest, in the areas you use. Turn off any you don’t inject."
        ) {
            ForEach(Array(areas.enumerated()), id: \.element) { index, area in
                ControlRow(symbol: area.symbol, tint: Color(hex: 0xFF375F), title: area.title, showsDivider: index < areas.count - 1) {
                    Toggle(area.title, isOn: isUsed(area))
                        .labelsHidden()
                        .tint(AppTheme.ColorToken.accent)
                        .disabled(isOnlyAreaInUse(area))
                }
            }
        }
    }

    private func isUsed(_ area: InjectionSite.Area) -> Binding<Bool> {
        Binding {
            !store.settings.skippedSiteAreas.contains(area)
        } set: { used in
            if used {
                store.settings.skippedSiteAreas.remove(area)
            } else {
                store.settings.skippedSiteAreas.insert(area)
            }
        }
    }

    private func isOnlyAreaInUse(_ area: InjectionSite.Area) -> Bool {
        let inUse = InjectionSite.Area.rotationAreas.filter { !store.settings.skippedSiteAreas.contains($0) }
        return inUse == [area]
    }
}

private extension InjectionSite.Area {
    var symbol: String {
        switch self {
        case .abdomen: "figure.core.training"
        case .thigh: "figure.walk"
        case .arm: "figure.strengthtraining.functional"
        case .glute: "figure.step.training"
        default: "figure.stand"
        }
    }
}

#Preview {
    NavigationStack { DosesSettingsView() }
        .environment(MedicineStore.preview())
}
