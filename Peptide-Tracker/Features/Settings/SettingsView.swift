import SwiftUI

/// The Settings tab, organised like iOS Settings: the profile, today's
/// check-in and Pro up top, then five sections — Reminders & doses, Health,
/// Care team, Reports & data, Appearance — each opening a page of its
/// options, then Help and About. Rows show what's set now.
struct SettingsView: View {
    @Environment(MedicineStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router
    /// Bumped after erasing (Reports & data), so the profile reloads its
    /// (now gone) photo.
    @AppStorage("settings.profileVersion") private var profileVersion = 0
    @AppStorage(AppLanguage.storageKey) private var languageRaw = ""
    @State private var isLanguagePickerPresented = false

    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .deviceDefault }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ProfileHeader()
                    .id(profileVersion)
                DailyCheckInCard()
                proCard

                GroupedSection {
                    SettingsLinkRow(page: .remindersGroup, value: store.settings.notificationsEnabled ? nil : String(localized: "Off"))
                    SettingsLinkRow(page: .health, value: store.latestWeight.map { store.settings.weightUnit.format($0.kilograms) })
                    SettingsLinkRow(page: .privacy, value: store.settings.appLock ? String(localized: "Locked") : nil)
                    SettingsLinkRow(page: .icloud, value: CloudSync.shared.summary)
                    SettingsLinkRow(page: .careTeam, value: store.trackingSummary)
                    SettingsLinkRow(page: .data, value: store.reportSummary)
                    SettingsLinkRow(page: .appearance, value: AppIconOption.current.title)
                    Button {
                        HapticFeedback.selection()
                        isLanguagePickerPresented = true
                    } label: {
                        SettingsRowLabel(symbol: "globe", tint: Color(hex: 0x0A84FF), title: String(localized: "Language"), value: "\(language.flag) \(language.nativeName)", showsChevron: true)
                    }
                    .buttonStyle(RowPressStyle())
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
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .readableWidth()
            .padding(.top, 20)
            .padding(.bottom, AppTheme.Spacing.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $isLanguagePickerPresented) { LanguagePickerSheet() }
        // Pinned, as on the other tabs: the title stays while rows scroll under.
        .safeAreaInset(edge: .top, spacing: 0) {
            TopPanel(title: String(localized: "Settings")) {
                AppearanceToggleButton()
                shareButton
            } controls: { EmptyView() }
        }
    }

    /// Tell a friend: the app's website.
    private var shareButton: some View {
        ShareLink(
            item: AppLinks.website,
            message: Text("I keep track of my medicines with \(Bundle.main.appName)."),
            preview: SharePreview(Bundle.main.appName)
        ) {
            Icon(.share, size: 20)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: 44, height: 44)
        }
        .compatGlass(interactive: true, in: .circle)
        .accessibilityLabel("Share \(Bundle.main.appName)")
    }

    // MARK: Pro

    /// The plan, for subscribers. Everyone in the app has Pro (hard
    /// paywall), so there's nothing to upgrade to.
    @ViewBuilder
    private var proCard: some View {
        if let plan = purchases.activePlan {
            GroupedSection {
                SettingsRowLabel(symbol: "crown.fill", tint: Color(hex: 0xFF9F0A), title: String(localized: "\(Bundle.main.appName) Pro"), value: plan.title)
            }
        }
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
