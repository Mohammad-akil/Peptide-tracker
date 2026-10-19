import SwiftUI

/// The Settings tab: reminder defaults, dose tracking, your pharmacy, your
/// data. Each group explains itself in a footer.
struct SettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router
    @State private var showsNotificationsDenied = false
    @State private var showsPrivacy = false
    @AppStorage(DoseLayout.storageKey) private var doseLayout: DoseLayout = .list
    #if DEBUG
    @State private var confirmsDeleteAll = false
    #endif

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(title: "Settings")

                GroupedSection(footer: proFooter) {
                    if let plan = purchases.activePlan {
                        ValueRow(title: "\(Bundle.main.appName) Pro", value: plan.title, showsDivider: false)
                    } else {
                        ValueRow(title: "Upgrade to Pro", value: "From \(purchases.price(for: .monthly))", valueTint: AppTheme.ColorToken.accent, showsDivider: false) {
                            router.sheet = .paywall(reason: nil)
                        }
                    }
                }

                GroupedSection(
                    title: "Reminders",
                    footer: "If you haven’t marked a medicine as ordered or refilled, we remind you again each morning."
                ) {
                    if !store.settings.notificationsEnabled {
                        ValueRow(title: "Notifications", value: "Turn on", valueTint: AppTheme.ColorToken.accent, action: enableNotifications)
                    }
                    HStack {
                        Text("Reminder time").font(.system(size: 17))
                        Spacer()
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
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .rowDivider(true)

                    HStack {
                        Text("Heads-up").font(.system(size: 17))
                        Spacer()
                        Menu {
                            Picker("Heads-up", selection: $store.settings.defaultDaysBefore) {
                                ForEach([1, 2, 3, 5, 7, 10, 14], id: \.self) { days in
                                    Text("\(days) \(days == 1 ? "day" : "days") before").tag(days)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("\(store.settings.defaultDaysBefore) \(store.settings.defaultDaysBefore == 1 ? "day" : "days") before")
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold))
                            }
                            .font(.system(size: 17))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .rowDivider(true)

                    ToggleRow(title: "Remind again until refilled", isOn: $store.settings.remindAgainUntilRefilled)
                }

                GroupedSection(
                    title: "Doses",
                    footer: store.settings.tracksDoses
                        ? "Timeline shows your doses down the day, with where you are now."
                        : "When on, ticking off doses keeps your count exact. When off, we count down from your schedule."
                ) {
                    ToggleRow(title: "Track doses", isOn: $store.settings.tracksDoses, showsDivider: store.settings.tracksDoses)
                    if store.settings.tracksDoses {
                        // How Today lays out the day's doses.
                        HStack {
                            Text("Dose view")
                                .font(.system(size: 17))
                                .foregroundStyle(AppTheme.ColorToken.primaryText)
                            Spacer(minLength: 8)
                            Picker("Dose view", selection: $doseLayout) {
                                ForEach(DoseLayout.allCases, id: \.self) { layout in
                                    Text(layout.title).tag(layout)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.ColorToken.secondaryText)
                            .labelsHidden()
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 8)
                        .frame(minHeight: 52)
                    }
                }
                .animation(.snappy, value: store.settings.tracksDoses)

                GroupedSection(title: "Pharmacy", footer: "Shown on medicine pages so you can call in one tap.") {
                    fieldRow("Pharmacy", placeholder: "Add", text: $store.settings.pharmacyName, showsDivider: true)
                    fieldRow("Phone", placeholder: "Add", text: $store.settings.pharmacyPhone, showsDivider: false)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                GroupedSection(title: "Your data", footer: "A PDF of your medicines and doses, handy for doctor visits.") {
                    ShareLink(
                        item: MedicineListPDF(medicines: store.medicinesByUrgency, pharmacyName: store.settings.pharmacyName, date: .now),
                        preview: SharePreview("Medicine list", image: Image(systemName: "doc.text"))
                    ) {
                        ValueRow(title: "Export medicine list", showsDivider: false)
                            .overlay(alignment: .trailing) { Chevron().padding(.trailing, 16) }
                            .contentShape(.rect)
                    }
                    .buttonStyle(RowPressStyle())
                    .disabled(store.medicines.isEmpty)
                }

                GroupedSection {
                    ValueRow(title: "Privacy") { showsPrivacy = true }
                    ValueRow(title: "Terms of Use") { openURL(AppLinks.termsOfUse) }
                    ValueRow(title: "Version", value: appVersion, showsDivider: false)
                }

                #if DEBUG
                GroupedSection(title: "Debug") {
                    ValueRow(title: "Load sample medicines") { store.loadSampleData() }
                    Menu {
                        Button("Success") { router.show(.success("Metformin added", message: "We’ll remind you on 9 Oct at 9:00.")) }
                        Button("Info") { router.show(.info("Reminders paused")) }
                        Button("Warning") { router.show(.warning("No earlier purchase found")) }
                        Button("Error") { router.show(.error("Purchase didn’t go through", message: "Check your connection and try again.")) }
                        Button("Loading, then success") {
                            Task {
                                await router.withLoadingToast(
                                    "Contacting the App Store…",
                                    success: .success("Purchase restored"),
                                    failureTitle: "Couldn’t restore"
                                ) { try await Task.sleep(for: .seconds(2)) }
                            }
                        }
                    } label: {
                        ValueRow(title: "Test toast", value: "Choose")
                    }
                    .buttonStyle(RowPressStyle())
                    ValueRow(title: "Delete all data", valueTint: AppTheme.ColorToken.destructive, showsDivider: false) {
                        confirmsDeleteAll = true
                    }
                }
                #endif
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, 8)
            .padding(.bottom, AppTheme.Spacing.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .sheet(isPresented: $showsPrivacy) { PrivacySheet() }
        .alert("Notifications are off", isPresented: $showsNotificationsDenied) {
            Button("Not now", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } message: {
            Text("Turn on notifications for this app in Settings to get refill reminders.")
        }
        #if DEBUG
        .confirmationDialog("Delete all medicines, doses and refills?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) { store.deleteAllData() }
        } message: {
            Text("You can’t undo this.")
        }
        #endif
    }

    private func fieldRow(_ title: String, placeholder: String, text: Binding<String>, showsDivider: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 17))
            TextField(title, text: text, prompt: Text(placeholder).foregroundStyle(AppTheme.ColorToken.accent))
                .multilineTextAlignment(.trailing)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .submitLabel(.done)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .rowDivider(showsDivider)
    }

    /// "1 of 2 free medicines used." for free users.
    private var proFooter: String? {
        guard !purchases.isPro else { return nil }
        let limit = PurchaseStore.freeMedicineLimit
        return "\(min(store.medicines.count, limit)) of \(limit) free medicines used. Pro tracks as many as you take."
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Asks iOS first; if the user said no before, point them to Settings.
    private func enableNotifications() {
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

/// What the app keeps and where.
private struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your medicines, doses and refills are saved only on this iPhone. There’s no account, and nothing is sent to us or anyone else.")
                    Text("Reminders are scheduled on the device. Exporting a medicine list creates a PDF that goes only where you choose to share it.")
                    Text("Deleting the app deletes everything it saved.")
                    Link("Read the full Privacy Policy", destination: AppLinks.privacyPolicy)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
                .font(.system(size: 17))
                .lineSpacing(3)
                .padding(20)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView()
        .environment(MedicineStore.preview())
        .environment(PurchaseStore())
        .environment(AppRouter())
        .background(AppTheme.ColorToken.background)
}
