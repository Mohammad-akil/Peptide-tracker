import SwiftUI

/// What the app keeps and where, the legal pages, and the version.
struct AboutSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        SettingsPageScaffold(page: .about) {
            GroupedSection(title: "Your privacy") {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Your medicines, doses and refills are saved only on this iPhone. There’s no account, and nothing is sent to us or anyone else.", systemImage: "iphone")
                    Label("Reminders are scheduled on the device. An exported medicine list goes only where you share it.", systemImage: "bell")
                    Label("Deleting the app deletes everything it saved.", systemImage: "trash")
                }
                .font(.system(size: 15))
                .lineSpacing(2)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .labelStyle(PrivacyPointStyle())
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupedSection {
                linkRow("Privacy Policy", symbol: "hand.raised.fill", tint: Color(hex: 0x0A84FF), url: AppLinks.privacyPolicy)
                linkRow("Terms of Use", symbol: "doc.text.fill", tint: Color(hex: 0x8E8E93), url: AppLinks.termsOfUse)
                linkRow("Website", symbol: "safari.fill", tint: Color(hex: 0x30B0C7), url: AppLinks.website, showsDivider: false)
            }

            GroupedSection {
                SettingsRowLabel(symbol: "globe", tint: Color(hex: 0x0A84FF), title: "Language", value: "Coming soon", valueTint: AppTheme.ColorToken.tertiaryText)
                    .rowDivider(true, inset: 58)
                SettingsRowLabel(symbol: "app.badge.fill", tint: AppTheme.ColorToken.accent, title: "Version", value: Self.version)
            }
        }
    }

    private func linkRow(_ title: String, symbol: String, tint: Color, url: URL, showsDivider: Bool = true) -> some View {
        Button { openURL(url) } label: {
            SettingsRowLabel(symbol: symbol, tint: tint, title: title, showsChevron: true)
                .rowDivider(showsDivider, inset: 58)
        }
        .buttonStyle(RowPressStyle())
    }

    /// "1.2 (14)"
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}

/// A privacy point: a small accent glyph beside its sentence.
private struct PrivacyPointStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            configuration.icon
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 20)
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack { AboutSettingsView() }
}
