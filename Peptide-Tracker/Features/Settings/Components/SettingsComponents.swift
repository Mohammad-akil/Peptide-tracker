import SwiftUI

/// The pages Settings opens, pushed onto the app's navigation stack. The
/// main list shows the five sections (`remindersGroup` … `appearance`);
/// each section's page lists the pages inside it.
enum SettingsPage: Hashable {
    case remindersGroup, health, careTeam, data, appearance
    case reminders, notifications, doses, pharmacy, contacts, tracking, report, help, about
    case privacy, travel, icloud
    #if DEBUG
    case developer
    #endif

    var title: String {
        switch self {
        case .remindersGroup: String(localized: "Reminders & doses")
        case .health: String(localized: "Health")
        case .careTeam: String(localized: "Care team")
        case .data: String(localized: "Reports & data")
        case .appearance: String(localized: "Appearance")
        case .reminders: String(localized: "Reminders")
        case .notifications: String(localized: "Notifications")
        case .doses: String(localized: "Doses")
        case .pharmacy: String(localized: "Pharmacy")
        case .contacts: String(localized: "Health contacts")
        case .tracking: String(localized: "Tracking for")
        case .report: String(localized: "Report")
        case .help: String(localized: "Help")
        case .about: String(localized: "About")
        case .privacy: String(localized: "Privacy")
        case .travel: String(localized: "Travel")
        case .icloud: String(localized: "iCloud sync")
        #if DEBUG
        case .developer: String(localized: "Developer")
        #endif
        }
    }

    var symbol: String {
        switch self {
        case .remindersGroup: "bell.fill"
        case .health: "heart.fill"
        case .careTeam: "stethoscope"
        case .data: "chart.bar.doc.horizontal.fill"
        case .appearance: "paintbrush.fill"
        case .reminders: "bell.fill"
        case .notifications: "bell.badge.fill"
        case .doses: "checklist"
        case .pharmacy: "cross.case.fill"
        case .contacts: "heart.text.square.fill"
        case .tracking: "person.2.fill"
        case .report: "chart.bar.fill"
        case .help: "questionmark.circle.fill"
        case .about: "info.circle.fill"
        case .privacy: "hand.raised.fill"
        case .travel: "airplane"
        case .icloud: "icloud.fill"
        #if DEBUG
        case .developer: "hammer.fill"
        #endif
        }
    }

    /// Each page's Apple system colour, for its tile.
    var tint: Color {
        switch self {
        case .remindersGroup: Color(hex: 0xFF453A) // red
        case .health: Color(hex: 0xFF375F)     // pink
        case .careTeam: Color(hex: 0x30B0C7)   // teal
        case .data: Color(hex: 0xBF5AF2)       // purple
        case .appearance: Color(hex: 0x5E5CE6) // indigo
        case .reminders: Color(hex: 0xFF453A)  // red
        case .notifications: Color(hex: 0xFF9F0A) // orange
        case .doses: Color(hex: 0x30D158)      // green
        case .pharmacy: Color(hex: 0x30B0C7)   // teal
        case .contacts: Color(hex: 0xFF375F)   // pink
        case .tracking: Color(hex: 0x0A84FF)   // blue
        case .report: Color(hex: 0xBF5AF2)     // purple
        case .help: Color(hex: 0x0A84FF)       // blue
        case .about: Color(hex: 0x8E8E93)      // grey
        case .privacy: Color(hex: 0x0A84FF)    // blue
        case .travel: Color(hex: 0xFF9F0A)     // orange
        case .icloud: Color(hex: 0x32ADE6)     // cyan
        #if DEBUG
        case .developer: Color(hex: 0x5E5CE6)  // indigo
        #endif
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .remindersGroup: RemindersGroupView()
        case .health: HealthGroupView()
        case .careTeam: CareTeamGroupView()
        case .data: DataGroupView()
        case .appearance: AppearanceGroupView()
        case .reminders: RemindersSettingsView()
        case .notifications: NotificationsSettingsView()
        case .doses: DosesSettingsView()
        case .pharmacy: PharmacySettingsView()
        case .contacts: HealthContactsSettingsView()
        case .tracking: TrackingSettingsView()
        case .report: ReportSettingsView()
        case .help: HelpSettingsView()
        case .about: AboutSettingsView()
        case .privacy: PrivacySettingsView()
        case .travel: TravelSettingsView()
        case .icloud: ICloudSettingsView()
        #if DEBUG
        case .developer: DeveloperSettingsView()
        #endif
        }
    }
}

/// A Settings row that opens a page: the coloured tile, the title, what's
/// set now in grey, and a chevron. The whole row is the button.
struct SettingsLinkRow: View {
    @Environment(AppRouter.self) private var router
    let page: SettingsPage
    var value: String?
    var showsDivider = true

    var body: some View {
        Button {
            HapticFeedback.selection()
            router.push(.settings(page))
        } label: {
            SettingsRowLabel(symbol: page.symbol, tint: page.tint, title: page.title, value: value, showsChevron: true)
                .rowDivider(showsDivider, inset: 58)
        }
        .buttonStyle(RowPressStyle())
    }
}

/// The inside of a Settings row: tile, title, value, chevron.
struct SettingsRowLabel: View {
    let symbol: String
    let tint: Color
    let title: String
    var value: String?
    var valueTint: Color = AppTheme.ColorToken.secondaryText
    var showsChevron = false

    var body: some View {
        HStack(spacing: 14) {
            SettingsTile(symbol: symbol, tint: tint)
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(valueTint)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            if showsChevron { Chevron() }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(.rect)
    }
}

/// A pushed Settings page: a small title centred in the bar, then its
/// groups, on the lavender ground.
struct SettingsPageScaffold<Content: View>: View {
    let page: SettingsPage
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .readableWidth()
            .padding(.top, 8)
            .padding(.bottom, AppTheme.Spacing.large)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Apple's pick-one row: a title, an optional line under it, and a
/// checkmark on the chosen one.
struct CheckRow: View {
    let title: String
    var detail: String?
    let isSelected: Bool
    var showsDivider = true
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.ColorToken.primaryText)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .rowDivider(showsDivider)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// "Pharmacy ·········· Boots" — a label with an inline text field.
struct FieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var showsDivider = true

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 17))
            TextField(title, text: $text, prompt: Text(placeholder).foregroundStyle(AppTheme.ColorToken.accent))
                .multilineTextAlignment(.trailing)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .submitLabel(.done)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .rowDivider(showsDivider)
    }
}
