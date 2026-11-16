import SwiftUI

// The five section pages under Settings. Each lists the options inside it,
// in the same grouped style as the main list, with what's set now in grey.

// MARK: - Summaries

/// What the main list and section pages show beside each row.
extension MedicineStore {
    /// "9:00 · 5d before", or "Off".
    var remindersSummary: String {
        guard settings.notificationsEnabled else { return "Off" }
        return "\(settings.defaultReminderTime.label) · \(settings.defaultDaysBefore)d before"
    }

    var pharmacySummary: String {
        let name = settings.pharmacyName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Add" : name
    }

    /// "Just me", or the person's name.
    var trackingSummary: String {
        let name = settings.personName.trimmingCharacters(in: .whitespaces)
        if settings.trackingFor != .me, !name.isEmpty { return name }
        return settings.trackingFor == .me ? "Just me" : "Someone else"
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
            GroupedSection(footer: "When refill reminders arrive, what they say, and how you tick off doses.") {
                SettingsLinkRow(page: .reminders, value: store.remindersSummary)
                SettingsLinkRow(page: .notifications, value: store.settings.showsMedicineName ? nil : "Names hidden")
                SettingsLinkRow(page: .doses, value: store.settings.tracksDoses ? doseLayout.title : "Off", showsDivider: false)
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

    var body: some View {
        SettingsPageScaffold(page: .health) {
            GroupedSection(title: "Tracking") {
                SettingsSheetRow(
                    title: "Mood",
                    value: store.checkIn(on: .now)?.mood.title ?? "Not logged",
                    action: { showsMood = true }
                ) {
                    SettingsTile(symbol: "face.smiling.inverse", tint: Color(hex: 0xBF5AF2))
                }
                SettingsSheetRow(
                    title: "Weight",
                    value: store.latestWeight.map { store.settings.weightUnit.format($0.kilograms) },
                    showsDivider: false,
                    action: { showsWeight = true }
                ) {
                    SettingsTile(symbol: "scalemass.fill", tint: Color(hex: 0x30B0C7))
                }
            }

            GroupedSection(title: "Calculators", footer: "Estimates with their sources. Save a result to follow your trend over time.") {
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
            GroupedSection(footer: "Who you track for, your pharmacy, and the people who look after you.") {
                SettingsLinkRow(page: .tracking, value: store.trackingSummary)
                SettingsLinkRow(page: .pharmacy, value: store.pharmacySummary)
                SettingsLinkRow(page: .contacts, value: store.contacts.isEmpty ? "Add" : "\(store.contacts.count)", showsDivider: false)
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
            GroupedSection(title: "Reports", footer: "PDFs of your medicines and how you’re doing, handy for doctor visits.") {
                SettingsLinkRow(page: .report, value: store.reportSummary)
                if purchases.isPro {
                    ShareLink(
                        item: MedicineListPDF(medicines: store.medicinesByUrgency, pharmacyName: store.settings.pharmacyName, date: .now),
                        preview: SharePreview("Medicine list", image: Image(systemName: "doc.text"))
                    ) {
                        SettingsRowLabel(symbol: "doc.text.fill", tint: Color(hex: 0xFF9F0A), title: "Export medicine list", showsChevron: true)
                    }
                    .buttonStyle(RowPressStyle())
                    .disabled(store.medicines.isEmpty)
                } else {
                    Button { router.sheet = .paywall(reason: "PDF exports for doctor visits are part of Pro.") } label: {
                        SettingsRowLabel(symbol: "doc.text.fill", tint: Color(hex: 0xFF9F0A), title: "Export medicine list")
                            .overlay(alignment: .trailing) { ProCrownBadge().padding(.trailing, 16) }
                    }
                    .buttonStyle(RowPressStyle())
                }
            }

            GroupedSection(title: "Your data", footer: "Every dose, medicine, refill, mood, weight and calculator result, as spreadsheets. Everything stays on this iPhone until you share it.") {
                ShareLink(
                    items: DataExportFile.all(from: store),
                    subject: Text("Doseday data"),
                    preview: { file in SharePreview(file.kind.fileName, image: Image(systemName: "tablecells")) }
                ) {
                    SettingsRowLabel(symbol: "square.and.arrow.down.fill", tint: Color(hex: 0x30D158), title: "Download your data", showsChevron: true)
                }
                .buttonStyle(RowPressStyle())
            }

            GroupedSection(footer: "Deletes every medicine, dose, refill, contact and setting on this iPhone. You can’t undo this.") {
                Button { confirmsErase = true } label: {
                    SettingsRowLabel(symbol: "trash.fill", tint: AppTheme.ColorToken.destructive, title: "Delete all data")
                }
                .buttonStyle(RowPressStyle())
            }
        }
        .confirmationDialog("Delete all your data?", isPresented: $confirmsErase, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) {
                store.eraseEverything()
                profileVersion += 1
                router.path = []
                router.showToast("All data deleted")
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
            GroupedSection(footer: "System follows your iPhone's Light and Dark Mode.") {
                AppearanceThemeRow()
            }
            GroupedSection(footer: "How \(Bundle.main.appName) looks on your Home Screen.") {
                SettingsSheetRow(title: "App icon", value: appIcon.title, showsDivider: false, action: { showsIconPicker = true }) {
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
