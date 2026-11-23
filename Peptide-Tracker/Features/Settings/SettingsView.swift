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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ProfileHeader()
                    .id(profileVersion)
                DailyCheckInCard()
                proCard

                GroupedSection {
                    SettingsLinkRow(page: .remindersGroup, value: store.settings.notificationsEnabled ? nil : "Off")
                    SettingsLinkRow(page: .health, value: store.latestWeight.map { store.settings.weightUnit.format($0.kilograms) })
                    SettingsLinkRow(page: .privacy, value: store.settings.appLock ? "Locked" : nil)
                    SettingsLinkRow(page: .careTeam, value: store.trackingSummary)
                    SettingsLinkRow(page: .data, value: store.reportSummary)
                    SettingsLinkRow(page: .appearance, value: AppIconOption.current.title, showsDivider: false)
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
        // Pinned, as on the other tabs: the title stays while rows scroll under.
        .safeAreaInset(edge: .top, spacing: 0) {
            TopPanel(title: "Settings") {
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

    /// Not Pro (rare behind the hard paywall): the way to Pro.
    /// Pro: the plan.
    @ViewBuilder
    private var proCard: some View {
        if let plan = purchases.activePlan {
            GroupedSection {
                SettingsRowLabel(symbol: "crown.fill", tint: Color(hex: 0xFF9F0A), title: "\(Bundle.main.appName) Pro", value: plan.title)
            }
        } else {
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
                        Text("Unlock every feature · From \(purchases.price(for: .monthly))")
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
