import SwiftUI

/// Whose medicines these are. Tracking for someone else puts their name in
/// reminders ("Mum’s Metformin is running low").
struct TrackingSettingsView: View {
    @Environment(MedicineStore.self) private var store

    var body: some View {
        @Bindable var store = store

        SettingsPageScaffold(page: .tracking) {
            GroupedSection(title: "Medicines for") {
                ForEach(Array(TrackingFor.allCases.enumerated()), id: \.element) { index, choice in
                    CheckRow(
                        title: choice.title,
                        isSelected: store.settings.trackingFor == choice,
                        showsDivider: index < TrackingFor.allCases.count - 1
                    ) { store.settings.trackingFor = choice }
                }
            }

            if store.settings.trackingFor != .me {
                GroupedSection(footer: footer) {
                    FieldRow(title: "Their name", placeholder: "Add", text: $store.settings.personName, showsDivider: false)
                        .textInputAutocapitalization(.words)
                        .textContentType(.givenName)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// "Reminders say “Mum’s Metformin”."
    private var footer: String {
        let name = store.settings.personName.trimmingCharacters(in: .whitespaces)
        let example = name.isEmpty ? "Mum’s" : "\(name)’s"
        return store.settings.trackingFor == .someoneElse
            ? "Reminders say “\(example) Metformin”."
            : "Reminders for their medicines say “\(example) Metformin”."
    }
}

#Preview {
    NavigationStack { TrackingSettingsView() }
        .environment(MedicineStore.preview())
}
