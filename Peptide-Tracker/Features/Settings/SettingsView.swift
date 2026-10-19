import SwiftUI

/// The Settings tab, in the same frame as Today and Medicines: the pinned
/// panel up top, the user's profile, then iOS Settings–style rows that each open their own page
/// (Reminders, Doses, Pharmacy, Tracking for, About). Each row shows what's
/// set now, so most visits never need to open one.
struct SettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router
    @AppStorage(DoseLayout.storageKey) private var doseLayout: DoseLayout = .list
    @State private var confirmsErase = false
    /// Bumped after erasing, so the profile reloads its (now gone) photo.
    @State private var profileVersion = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ProfileHeader()
                    .id(profileVersion)
                DailyCheckInCard()
                proCard

                GroupedSection {
                    SettingsLinkRow(page: .reminders, value: remindersValue)
                    SettingsLinkRow(page: .notifications, value: store.settings.showsMedicineName ? nil : "Names hidden")
                    SettingsLinkRow(page: .doses, value: dosesValue)
                    SettingsLinkRow(page: .pharmacy, value: pharmacyValue)
                    SettingsLinkRow(page: .contacts, value: store.contacts.isEmpty ? "Add" : "\(store.contacts.count)")
                    SettingsLinkRow(page: .tracking, value: trackingValue, showsDivider: false)
                }

                GroupedSection(footer: "PDFs of your medicines and how you’re doing, handy for doctor visits.") {
                    SettingsLinkRow(page: .report, value: reportValue)
                    ShareLink(
                        item: MedicineListPDF(medicines: store.medicinesByUrgency, pharmacyName: store.settings.pharmacyName, date: .now),
                        preview: SharePreview("Medicine list", image: Image(systemName: "doc.text"))
                    ) {
                        SettingsRowLabel(symbol: "square.and.arrow.up.fill", tint: Color(hex: 0xFF9F0A), title: "Export medicine list", showsChevron: true)
                    }
                    .buttonStyle(RowPressStyle())
                    .disabled(store.medicines.isEmpty)
                }

                GroupedSection {
                    SettingsLinkRow(page: .help)
                    #if DEBUG
                    SettingsLinkRow(page: .about, value: AboutSettingsView.version)
                    SettingsLinkRow(page: .developer, showsDivider: false)
                    #else
                    SettingsLinkRow(page: .about, value: AboutSettingsView.version, showsDivider: false)
                    #endif
                }

                GroupedSection(footer: "Deletes every medicine, dose, refill, contact and setting on this iPhone. You can’t undo this.") {
                    Button { confirmsErase = true } label: {
                        SettingsRowLabel(symbol: "trash.fill", tint: AppTheme.ColorToken.destructive, title: "Delete all data")
                    }
                    .buttonStyle(RowPressStyle())
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, 20)
            .padding(.bottom, AppTheme.Spacing.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        // Pinned, as on the other tabs: the title stays while rows scroll under.
        .safeAreaInset(edge: .top, spacing: 0) {
            TopPanel(title: "Settings") { EmptyView() } controls: { EmptyView() }
        }
        .confirmationDialog("Delete all your data?", isPresented: $confirmsErase, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) {
                store.eraseEverything()
                profileVersion += 1
                router.showToast("All data deleted")
            }
        } message: {
            Text("Every medicine, dose, refill, contact and setting is removed from this iPhone. You can’t undo this.")
        }
    }

    // MARK: Pro

    /// Free: the way to Pro, with how much of the free limit is used.
    /// Pro: the plan.
    @ViewBuilder
    private var proCard: some View {
        if let plan = purchases.activePlan {
            GroupedSection {
                SettingsRowLabel(symbol: "crown.fill", tint: Color(hex: 0xFF9F0A), title: "\(Bundle.main.appName) Pro", value: plan.title)
            }
        } else {
            let limit = PurchaseStore.freeMedicineLimit
            let used = min(store.medicines.count, limit)
            Button { router.sheet = .paywall(reason: nil) } label: {
                HStack(spacing: 14) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            LinearGradient(colors: [Color(hex: 0x8A6CF0), AppTheme.ColorToken.accent], startPoint: .top, endPoint: .bottom),
                            in: .rect(cornerRadius: 13, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Upgrade to Pro")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.primaryText)
                        Text("\(used) of \(limit) free medicines used · From \(purchases.price(for: .monthly))")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Chevron()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(.rect)
            }
            .buttonStyle(RowPressStyle())
            .groupedCard()
        }
    }

    // MARK: Row values

    /// "9:00 · 5d before", or "Off".
    private var remindersValue: String {
        let settings = store.settings
        guard settings.notificationsEnabled else { return "Off" }
        return "\(settings.defaultReminderTime.label) · \(settings.defaultDaysBefore)d before"
    }

    /// The last 30 days' rate ("92%"), once anything was due.
    private var reportValue: String? {
        AdherenceReport(store: store, period: .month).rate?.percentLabel
    }

    /// "List", "Timeline", or "Off".
    private var dosesValue: String {
        store.settings.tracksDoses ? doseLayout.title : "Off"
    }

    private var pharmacyValue: String {
        let name = store.settings.pharmacyName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Add" : name
    }

    /// "Just me", or the person's name.
    private var trackingValue: String {
        let name = store.settings.personName.trimmingCharacters(in: .whitespaces)
        if store.settings.trackingFor != .me, !name.isEmpty { return name }
        return store.settings.trackingFor == .me ? "Just me" : "Someone else"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(MedicineStore.preview())
    .environment(PurchaseStore())
    .environment(AppRouter())
    .background(AppTheme.ColorToken.background)
}
