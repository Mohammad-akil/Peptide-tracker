import SwiftUI

// MARK: - Buttons

/// The filled accent capsule — "Refill", "Add your first medicine",
/// "Confirm · 56 pills".
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    var fullWidth = true
    var tint: Color = AppTheme.ColorToken.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: height < 48 ? 15 : 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, height < 48 ? 16 : 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .background(tint, in: .capsule)
            .shadow(color: tint.opacity(0.32), radius: 12, y: 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(height: CGFloat, fullWidth: Bool = true) -> PrimaryButtonStyle {
        PrimaryButtonStyle(height: height, fullWidth: fullWidth)
    }
}

/// The accent capsule in tinted Liquid Glass — onboarding's buttons.
struct GlassPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 55
    var tint: Color = AppTheme.ColorToken.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(.capsule)
            .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static var glassPrimary: GlassPrimaryButtonStyle { GlassPrimaryButtonStyle() }
}

/// Gentle press feedback for cards and rows that are tappable as a whole.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}
