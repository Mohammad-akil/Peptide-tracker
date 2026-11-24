import SwiftUI

// The five section pages under Settings. Each lists the options inside it,
// in the same grouped style as the main list, with what's set now in grey.

// MARK: - Summaries

/// What the main list and section pages show beside each row.
extension MedicineStore {
    /// "9:00 · 5d before", or "Off".
    var remindersSummary: String {
        guard settings.notificationsEnabled else { return String(localized: "Off") }
        return String(localized: "\(settings.defaultReminderTime.label) · \(settings.defaultDaysBefore)d before")
    }

    var pharmacySummary: String {
        let name = settings.pharmacyName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: "Add") : name
    }

    /// "Just me", or the person's name.
    var trackingSummary: String {
        let name = settings.personName.trimmingCharacters(in: .whitespaces)
        if settings.trackingFor != .me, !name.isEmpty { return name }
        return settings.trackingFor == .me ? String(localized: "Just me") : String(localized: "Someone else")
    }

    /// The last 30 days' rate ("92%"), once anything was due.
    var reportSummary: String? {
        adherenceReport(.month).rate?.percentLabel
    }
}

/// A row that opens a sheet rather than a page: tile or image, title,
/// value, chevron.
struct SettingsSheetRow<Icon: View>: View {
    let title: String
    var value: String?
    var showsDivider = true
    let action: () -> Void
    @ViewBuilder var icon: Icon

    var body: some View {
        Button {
            HapticFeedback.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                icon
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(.system(size: 17))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.ColorToken.secondaryText)
                        .lineLimit(1)
                }
                Chevron()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .rowDivider(showsDivider, inset: 60)
        }
        .buttonStyle(RowPressStyle())
    }
}

// MARK: - Reminders & doses

struct RemindersGroupView: View {
    @Environment(MedicineStore.self) private var store
    @AppStorage(DoseLayout.storageKey) private var doseLayout: DoseLayout = .list

    var body: some View {
        SettingsPageScaffold(page: .remindersGroup) {
            GroupedSection(footer: String(localized: "When refill reminders arrive, what they say, and how you tick off doses.")) {
                SettingsLinkRow(page: .reminders, value: store.remindersSummary)
                SettingsLinkRow(page: .notifications, value: store.settings.showsMedicineName ? nil : String(localized: "Names hidden"))
                SettingsLinkRow(page: .doses, value: store.settings.tracksDoses ? doseLayout.title : String(localized: "Off"))
                SettingsLinkRow(page: .travel, value: store.settings.keepsHomeTime ? String(localized: "Home time") : nil, showsDivider: false)
            }
        }
    }
}

// MARK: - Health

struct HealthGroupView: View {
    @Environment(MedicineStore.self) private var store
    @State private var calculator: HealthCalculator?
    @State private var showsWeight = false
    @State private var showsMood = false
    @State private var showsSideEffects = false
    @State private var showsSharps = false

    var body: some View {
        SettingsPageScaffold(page: .health) {
            GroupedSection(title: String(localized: "Tracking")) {
                SettingsSheetRow(
                    title: String(localized: "Mood"),
                    value: store.checkIn(on: .now)?.mood.title ?? String(localized: "Not logged"),
                    action: { showsMood = true }
                ) {
                    SettingsTile(symbol: "face.smiling.inverse", tint: Color(hex: 0xBF5AF2))
                }
                SettingsSheetRow(
                    title: String(localized: "Weight"),
                    value: store.latestWeight.map { store.settings.weightUnit.format($0.kilograms) },
                    action: { showsWeight = true }
                ) {
                    SettingsTile(symbol: "scalemass.fill", tint: Color(hex: 0x30B0C7))
                }
                SettingsSheetRow(
                    title: String(localized: "Side effects"),
                    value: store.sideEffects.isEmpty ? String(localized: "Log") : String(localized: "\(store.sideEffects(lastDays: 30).count) this month"),
                    showsDivider: store.medicines.contains { $0.type == .injection } || store.settings.tracksSharps,
                    action: { showsSideEffects = true }
                ) {
                    SettingsTile(symbol: "list.bullet.clipboard.fill", tint: Color(hex: 0xFF453A))
                }
                if store.medicines.contains(where: { $0.type == .injection }) || store.settings.tracksSharps {
                    SettingsSheetRow(
                        title: String(localized: "Sharps container"),
                        value: store.sharpsSummary,
                        showsDivider: false,
                        action: { showsSharps = true }
                    ) {
                        SettingsTile(symbol: "trash.square.fill", tint: Color(hex: 0xFF9F0A))
                    }
                }
            }

            GroupedSection(title: String(localized: "Calculators"), footer: String(localized: "Estimates with their sources. Save a result to follow your trend over time.")) {
                ForEach(Array(HealthCalculator.allCases.enumerated()), id: \.element) { index, kind in
                    SettingsSheetRow(
                        title: kind.title,
                        value: store.calculatorResults(for: kind).last.map { kind.format($0.value) },
                        showsDivider: index < HealthCalculator.allCases.count - 1,
                        action: { calculator = kind }
                    ) {
                        kind.illustration.resizable().scaledToFit()
                    }
                }
            }
        }
        .sheet(item: $calculator) { CalculatorSheet(kind: $0) }
        .sheet(isPresented: $showsWeight) { WeightSheet() }
        .sheet(isPresented: $showsSideEffects) { SideEffectsSheet() }
        .sheet(isPresented: $showsSharps) { SharpsSheet() }
        .sheet(isPresented: $showsMood) {
            MoodSheet().presentationDetents([.large])
        }
    }
}

// MARK: - Care team

struct CareTeamGroupView: View {
    @Environment(MedicineStore.self) private var store

    var body: some View {
        SettingsPageScaffold(page: .careTeam) {
            GroupedSection(footer: String(localized: "Who you track for, your pharmacy, and the people who look after you.")) {
                SettingsLinkRow(page: .tracking, value: store.trackingSummary)
                SettingsLinkRow(page: .pharmacy, value: store.pharmacySummary)
                SettingsLinkRow(page: .contacts, value: store.contacts.isEmpty ? String(localized: "Add") : "\(store.contacts.count)", showsDivider: false)
            }
        }
    }
}

// MARK: - Reports & data

struct DataGroupView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router
    @AppStorage("settings.profileVersion") private var profileVersion = 0
    @State private var confirmsErase = false

    var body: some View {
        SettingsPageScaffold(page: .data) {
            GroupedSection(title: String(localized: "Reports"), footer: String(localized: "PDFs of your medicines and how you’re doing, handy for doctor visits.")) {
                SettingsLinkRow(page: .report, value: store.reportSummary)
                ShareLink(
                    item: MedicineListPDF(medicines: store.medicinesByUrgency, pharmacyName: store.settings.pharmacyName, date: .now),
                    preview: SharePreview(String(localized: "Medicine list"), image: Image(systemName: "doc.text"))
                ) {
                    SettingsRowLabel(symbol: "doc.text.fill", tint: Color(hex: 0xFF9F0A), title: String(localized: "Export medicine list"), showsChevron: true)
                }
                .buttonStyle(RowPressStyle())
                .disabled(store.medicines.isEmpty)
            }

            GroupedSection(title: String(localized: "Your data"), footer: String(localized: "Every dose, medicine, refill, mood, weight and calculator result, as spreadsheets. Everything stays on this iPhone until you share it.")) {
                ShareLink(
                    items: DataExportFile.all(from: store),
                    subject: Text("Doseday data"),
                    preview: { file in SharePreview(file.kind.fileName, image: Image(systemName: "tablecells")) }
                ) {
                    SettingsRowLabel(symbol: "square.and.arrow.down.fill", tint: Color(hex: 0x30D158), title: String(localized: "Download your data"), showsChevron: true)
                }
                .buttonStyle(RowPressStyle())
            }

            GroupedSection(footer: String(localized: "Deletes every medicine, dose, refill, contact and setting on this iPhone. You can’t undo this.")) {
                Button { confirmsErase = true } label: {
                    SettingsRowLabel(symbol: "trash.fill", tint: AppTheme.ColorToken.destructive, title: String(localized: "Delete all data"))
                }
                .buttonStyle(RowPressStyle())
            }
        }
        .confirmationDialog("Delete all your data?", isPresented: $confirmsErase, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) {
                store.eraseEverything()
                profileVersion += 1
                router.path = []
                router.showToast(String(localized: "All data deleted"))
            }
        } message: {
            Text("Every medicine, dose, refill, contact and setting is removed from this iPhone. You can’t undo this.")
        }
    }
}

// MARK: - Appearance

struct AppearanceGroupView: View {
    @State private var showsIconPicker = false
    /// Re-read when the picker closes, so the row shows the new icon.
    @State private var appIcon = AppIconOption.current

    var body: some View {
        SettingsPageScaffold(page: .appearance) {
            GroupedSection(footer: String(localized: "System follows your iPhone's Light and Dark Mode.")) {
                AppearanceThemeRow()
            }
            GroupedSection(footer: String(localized: "How \(Bundle.main.appName) looks on your Home Screen.")) {
                SettingsSheetRow(title: String(localized: "App icon"), value: appIcon.title, showsDivider: false, action: { showsIconPicker = true }) {
                    appIcon.preview
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 7, style: .continuous))
                }
            }
        }
        .sheet(isPresented: $showsIconPicker, onDismiss: { appIcon = AppIconOption.current }) {
            AppIconPicker()
        }
    }
}
