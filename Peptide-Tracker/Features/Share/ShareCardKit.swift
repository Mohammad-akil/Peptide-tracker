import SwiftUI

// Building blocks every share card is drawn with (same approach as Plates).
// Cards are laid out at a fixed point size and rendered at 3×, so a 360pt
// card exports 1080px wide, the width Instagram and TikTok expect. Fixed
// sizes, not Dynamic Type, so the image looks the same on every phone.
//
// Privacy: cards never show medicine names, doses or amounts, only
// counts, rates and moods, so sharing never gives away what someone takes.

/// The canvas a card is exported at.
enum ShareCardFormat: String, CaseIterable, Identifiable {
    /// 9:16, stories (1080 × 1920).
    case story
    /// 4:5, feed posts (1080 × 1350).
    case post

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .story: CGSize(width: 360, height: 640)
        case .post: CGSize(width: 360, height: 450)
        }
    }

    var label: String { self == .story ? String(localized: "Story") : String(localized: "Post") }
    var isStory: Bool { self == .story }
}

/// The backdrop and ink a card is drawn in. Every card supports all four.
enum ShareCardTheme: String, CaseIterable, Identifiable {
    case brand, dark, light
    /// No backdrop: a see-through PNG to drop on a story as a sticker.
    case clear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .brand: String(localized: "Doseday")
        case .dark: String(localized: "Dark")
        case .light: String(localized: "Light")
        case .clear: String(localized: "Clear")
        }
    }

    static let violet = Color(red: 0.416, green: 0.271, blue: 0.847)   // #6A45D8
    static let lilac = Color(red: 0.722, green: 0.627, blue: 1.0)
    static let pink = Color(red: 0.98, green: 0.47, blue: 0.75)

    var primary: Color { self == .light ? Color(red: 0.07, green: 0.08, blue: 0.09) : .white }

    var secondary: Color {
        switch self {
        case .light: Color.black.opacity(0.5)
        case .clear: .white.opacity(0.85)
        case .brand: .white.opacity(0.72)
        case .dark: .white.opacity(0.6)
        }
    }

    /// Tiles and chips sitting on the card.
    var surface: Color {
        switch self {
        case .light: .white
        case .brand: .white.opacity(0.12)
        case .clear: .white.opacity(0.16)
        case .dark: .white.opacity(0.07)
        }
    }

    /// Unfilled tracks and empty squares.
    var subtle: Color {
        switch self {
        case .light: Color.black.opacity(0.08)
        case .brand, .clear: .white.opacity(0.2)
        case .dark: .white.opacity(0.12)
        }
    }

    /// Filled bars, rings and the "done" colour.
    var accent: Color {
        switch self {
        case .light: Self.violet
        case .dark: Self.lilac
        case .brand, .clear: .white
        }
    }

    /// The ink drawn on top of `accent`.
    var onAccent: Color {
        switch self {
        case .brand: Self.violet
        case .clear: Color(red: 0.2, green: 0.12, blue: 0.45)
        case .dark: Color(red: 0.1, green: 0.07, blue: 0.2)
        case .light: .white
        }
    }

    /// A softer accent for "some doses" squares.
    var partial: Color { accent.opacity(0.45) }

    @ViewBuilder var background: some View {
        switch self {
        case .clear:
            Color.clear
        case .brand:
            ZStack {
                LinearGradient(colors: [Color(red: 0.31, green: 0.18, blue: 0.75), Color(red: 0.2, green: 0.1, blue: 0.5)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Self.pink.opacity(0.4), .clear], center: .init(x: 0.95, y: 0.02), startRadius: 0, endRadius: 330)
                RadialGradient(colors: [Self.lilac.opacity(0.35), .clear], center: .init(x: 0.0, y: 1.0), startRadius: 0, endRadius: 340)
            }
        case .dark:
            ZStack {
                Color(red: 0.055, green: 0.051, blue: 0.075)
                RadialGradient(colors: [Self.violet.opacity(0.42), .clear], center: .init(x: 0.9, y: 0.0), startRadius: 0, endRadius: 360)
            }
        case .light:
            ZStack {
                Color(red: 0.965, green: 0.96, blue: 0.984)
                RadialGradient(colors: [Self.violet.opacity(0.14), .clear], center: .init(x: 0.9, y: 0.0), startRadius: 0, endRadius: 340)
            }
        }
    }

    /// Swatch in the sheet's theme picker.
    @ViewBuilder var swatch: some View {
        if self == .clear { ShareCardCheckerboard() } else { background }
    }
}

enum ShareCardFont {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// One card the sheet can show and export.
struct ShareCardVariant: Identifiable {
    var id: String
    var name: String
    var systemImage: String
    var card: (ShareCardFormat, ShareCardTheme) -> AnyView

    init<Card: View>(id: String, name: String, systemImage: String,
                     @ViewBuilder card: @escaping (ShareCardFormat, ShareCardTheme) -> Card) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.card = { AnyView(card($0, $1)) }
    }
}

/// Margins, the corner chip, the footer and the backdrop shared by every card.
struct ShareCardScaffold<Content: View>: View {
    var format: ShareCardFormat
    var theme: ShareCardTheme
    var eyebrow: String
    var eyebrowIcon: String
    var footnote: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ShareCardFooter(theme: theme, footnote: footnote)
                .padding(.top, 14)
        }
        .padding(.horizontal, 26)
        .padding(.top, format.isStory ? 56 : 46)
        .padding(.bottom, format.isStory ? 30 : 22)
        .frame(width: format.size.width, height: format.size.height)
        .overlay(alignment: .topLeading) {
            ShareCardEyebrow(text: eyebrow, systemImage: eyebrowIcon, theme: theme)
                .padding(.top, format.isStory ? 22 : 16)
                .padding(.leading, 22)
        }
        .background { theme.background }
        .clipped()
        // An image: keep system colours from following the phone's mode.
        .environment(\.colorScheme, theme == .light ? .light : .dark)
    }
}

/// App icon and wordmark, with a caption (usually the date) on the right.
struct ShareCardFooter: View {
    var theme: ShareCardTheme
    var footnote: String?

    var body: some View {
        HStack(spacing: 8) {
            Image("IconPreview-Classic")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("Doseday")
                .font(ShareCardFont.rounded(15, .bold))
                .foregroundStyle(theme.primary)
            Spacer(minLength: 8)
            if let footnote {
                Text(footnote)
                    .font(ShareCardFont.rounded(11, .semibold))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// The small all-caps chip in the top corner ("TODAY", "THIS WEEK").
struct ShareCardEyebrow: View {
    var text: String
    var systemImage: String
    var theme: ShareCardTheme

    var body: some View {
        Label(text.uppercased(), systemImage: systemImage)
            .font(ShareCardFont.rounded(11, .bold))
            .tracking(1)
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.surface, in: Capsule())
    }
}

/// A number with its label under it.
struct ShareCardStat: View {
    var value: String
    var label: String
    var theme: ShareCardTheme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ShareCardFont.rounded(22, .heavy))
                .foregroundStyle(theme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(ShareCardFont.rounded(11, .semibold))
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Grey/white checks behind the clear theme in the preview and its swatch.
/// Never part of the export.
struct ShareCardCheckerboard: View {
    var cell: CGFloat = 6
    var base: Color = .white
    var check = Color(white: 0.8)

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            for row in 0..<Int((size.height / cell).rounded(.up)) {
                for column in 0..<Int((size.width / cell).rounded(.up)) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(check))
                }
            }
        }
    }
}
