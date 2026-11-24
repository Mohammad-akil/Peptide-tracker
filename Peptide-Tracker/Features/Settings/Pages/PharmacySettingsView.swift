import SwiftUI

/// Your pharmacy: its name and number, shown on medicine pages so you can
/// call in one tap, and how your refills usually arrive.
struct PharmacySettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var store = store
        let phone = store.settings.pharmacyPhone.filter { $0.isNumber || $0 == "+" }

        SettingsPageScaffold(page: .pharmacy) {
            GroupedSection(footer: String(localized: "Shown on medicine pages so you can call in one tap.")) {
                FieldRow(title: String(localized: "Name"), placeholder: String(localized: "Add"), text: $store.settings.pharmacyName)
                    .textContentType(.organizationName)
                FieldRow(title: String(localized: "Phone"), placeholder: String(localized: "Add"), text: $store.settings.pharmacyPhone, showsDivider: !phone.isEmpty)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                if !phone.isEmpty, let url = URL(string: "tel:\(phone)") {
                    Button { openURL(url) } label: {
                        SettingsRowLabel(symbol: "phone.fill", tint: Color(hex: 0x30D158), title: String(localized: "Call pharmacy"))
                    }
                    .buttonStyle(RowPressStyle())
                    .transition(.opacity)
                }
            }
            .animation(.snappy, value: phone.isEmpty)

            GroupedSection(title: String(localized: "How refills arrive")) {
                ForEach(Array(PharmacyKind.allCases.enumerated()), id: \.element) { index, kind in
                    CheckRow(
                        title: kind.title,
                        detail: detail(for: kind),
                        isSelected: store.settings.pharmacyKind == kind,
                        showsDivider: index < PharmacyKind.allCases.count - 1
                    ) { store.settings.pharmacyKind = kind }
                }
            }
        }
    }

    private func detail(for kind: PharmacyKind) -> String {
        switch kind {
        case .one: String(localized: "You pick up from the same place.")
        case .delivery: String(localized: "Refills come by post, so allow a few extra days.")
        case .varies: String(localized: "Different places, depending on the medicine.")
        }
    }
}

#Preview {
    NavigationStack { PharmacySettingsView() }
        .environment(MedicineStore.preview())
}
