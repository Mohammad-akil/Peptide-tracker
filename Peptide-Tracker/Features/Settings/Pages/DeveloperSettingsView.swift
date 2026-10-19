#if DEBUG
import SwiftUI

/// Testing tools, only in debug builds: sample data, every toast style,
/// and wiping everything.
struct DeveloperSettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var confirmsDeleteAll = false

    var body: some View {
        SettingsPageScaffold(page: .developer) {
            GroupedSection(title: "Data") {
                actionRow("Load sample medicines", symbol: "tray.and.arrow.down.fill", tint: Color(hex: 0x0A84FF)) {
                    store.loadSampleData()
                    router.showToast("Sample medicines loaded")
                }
                actionRow("Delete all data", symbol: "trash.fill", tint: AppTheme.ColorToken.destructive, showsDivider: false) {
                    confirmsDeleteAll = true
                }
            }

            GroupedSection(title: "Test toasts") {
                actionRow("Success", symbol: "checkmark.circle.fill", tint: Toast.Style.success.tint) {
                    router.show(.success("Metformin added", message: "We’ll remind you on 9 Oct at 9:00."))
                }
                actionRow("Info", symbol: "info.circle.fill", tint: Toast.Style.info.tint) {
                    router.show(.info("Reminders paused"))
                }
                actionRow("Warning", symbol: "exclamationmark.triangle.fill", tint: Toast.Style.warning.tint) {
                    router.show(.warning("No earlier purchase found"))
                }
                actionRow("Error", symbol: "xmark.octagon.fill", tint: Toast.Style.error.tint) {
                    router.show(.error("Purchase didn’t go through", message: "Check your connection and try again."))
                }
                actionRow("Loading, then success", symbol: "circle.dotted", tint: Toast.Style.loading.tint, showsDivider: false) {
                    Task {
                        await router.withLoadingToast(
                            "Contacting the App Store…",
                            success: .success("Purchase restored"),
                            failureTitle: "Couldn’t restore"
                        ) { try await Task.sleep(for: .seconds(2)) }
                    }
                }
            }
        }
        .confirmationDialog("Delete all medicines, doses and refills?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) { store.deleteAllData() }
        } message: {
            Text("You can’t undo this.")
        }
    }

    private func actionRow(_ title: String, symbol: String, tint: Color, showsDivider: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsRowLabel(symbol: symbol, tint: tint, title: title)
                .rowDivider(showsDivider, inset: 58)
        }
        .buttonStyle(RowPressStyle())
    }
}

#Preview {
    NavigationStack { DeveloperSettingsView() }
        .environment(MedicineStore.preview())
        .environment(AppRouter())
}
#endif
