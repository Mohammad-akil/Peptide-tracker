import SwiftUI
import UIKit

/// Semantic design tokens shared across features — lifted straight from the
/// "Medicine Refill Tracker" design canvas so every screen draws from one
/// palette instead of repeating hex values.
enum AppTheme {
    enum ColorToken {
        /// The lavender-tinted page ground behind every tab.
        static let background = Color(light: 0xF6F5FB, dark: 0x0E0D13)
        /// Raised white cards.
        static let cardBackground = Color(light: 0xFFFFFF, dark: 0x1C1A24)
        static let primaryText = Color(light: 0x111418, dark: 0xF4F3F8)
        static let secondaryText = Color(light: 0x5F6670, dark: 0xA3A8B2)
        static let tertiaryText = Color(light: 0x9AA0A8, dark: 0x70757E)

        static let accent = Color(hex: 0x6A45D8)
        /// Pale accent wash for icon tiles and info banners.
        static let accentSoft = Color(light: 0xEFEAFD, dark: 0x2A2145)
        /// Dark accent ink for text sitting on `accentSoft`.
        static let accentInk = Color(light: 0x3A2380, dark: 0xD9CFFA)
        /// Inactive bars and partial-day dots.
        static let accentMuted = Color(light: 0xD9CFFA, dark: 0x463A73)

        static let separator = Color(light: 0x3C3C43, dark: 0xFFFFFF).opacity(0.14)
        /// The neutral grey fill behind segmented controls and steppers.
        static let controlFill = Color(light: 0x767680, dark: 0x9A9AA6).opacity(0.12)
        static let ringTrack = Color(light: 0xE9EBEF, dark: 0x2C2A36)
        static let uncheckedRing = Color(light: 0xCFCBDC, dark: 0x4C4858)
        static let dashedBorder = Color(light: 0xC7C1DA, dark: 0x4C4858)

        static let destructive = Color(hex: 0xC8372D)
    }

    enum Radius {
        static let card: CGFloat = 24
        static let tile: CGFloat = 22
        static let field: CGFloat = 18
    }

    enum Spacing {
        static let xxSmall: CGFloat = 2
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let smallMedium: CGFloat = 12
        static let cardGap: CGFloat = 14
        static let medium: CGFloat = 16
        static let mediumLarge: CGFloat = 20
        static let large: CGFloat = 24
        /// Room kept under scroll content so the floating tab bar never
        /// covers the last card.
        static let tabBarClearance: CGFloat = 120
    }
}

// MARK: - Hex helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A colour that follows the system appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
