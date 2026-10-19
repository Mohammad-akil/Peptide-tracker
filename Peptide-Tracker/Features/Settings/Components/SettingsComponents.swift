import SwiftUI

/// The pages Settings opens, pushed onto the app's navigation stack.
enum SettingsPage: Hashable {
    case reminders, notifications, doses, pharmacy, contacts, tracking, report, help, about
    #if DEBUG
    case developer
    #endif

    var title: String {
        switch self {
        case .reminders: "Reminders"
        case .notifications: "Notifications"
        case .doses: "Doses"
        case .pharmacy: "Pharmacy"
        case .contacts: "Health contacts"
        case .tracking: "Tracking for"
        case .report: "Report"
        case .help: "Help"
        case .about: "About"
        #if DEBUG
        case .developer: "Developer"
        #endif
        }
    }

    var symbol: String {
        switch self {
        case .reminders: "bell.fill"
        case .notifications: "bell.badge.fill"
        case .doses: "checklist"
        case .pharmacy: "cross.case.fill"
        case .contacts: "heart.text.square.fill"
        case .tracking: "person.2.fill"
        case .report: "chart.bar.fill"
        case .help: "questionmark.circle.fill"
        case .about: "info.circle.fill"
        #if DEBUG
        case .developer: "hammer.fill"
        #endif
        }
    }

    /// Each page's Apple system colour, for its tile.
    var tint: Color {
        switch self {
        case .reminders: Color(hex: 0xFF453A)  // red
        case .notifications: Color(hex: 0xFF9F0A) // orange
        case .doses: Color(hex: 0x30D158)      // green
        case .pharmacy: Color(hex: 0x30B0C7)   // teal
        case .contacts: Color(hex: 0xFF375F)   // pink
        case .tracking: Color(hex: 0x0A84FF)   // blue
        case .report: Color(hex: 0xBF5AF2)     // purple
        case .help: Color(hex: 0x0A84FF)       // blue
        case .about: Color(hex: 0x8E8E93)      // grey
        #if DEBUG
        case .developer: Color(hex: 0x5E5CE6)  // indigo
        #endif
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .reminders: RemindersSettingsView()
        case .notifications: NotificationsSettingsView()
        case .doses: DosesSettingsView()
        case .pharmacy: PharmacySettingsView()
        case .contacts: HealthContactsSettingsView()
        case .tracking: TrackingSettingsView()
        case .report: ReportSettingsView()
        case .help: HelpSettingsView()
        case .about: AboutSettingsView()
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

/// A pushed Settings page: a large title (or a small centred one), then
/// its groups, on the lavender ground.
struct SettingsPageScaffold<Content: View>: View {
    let page: SettingsPage
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, 8)
            .padding(.bottom, AppTheme.Spacing.large)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(titleDisplayMode)
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
