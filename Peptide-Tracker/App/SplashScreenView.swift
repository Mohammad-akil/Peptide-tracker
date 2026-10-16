import SwiftUI
import UIKit

/// Launch splash, picking up exactly where `LaunchScreen.storyboard` leaves
/// off (same icon, size and colour): a spring entrance, a slow ambient drift
/// while the app decides where to start, then a short exit as the first
/// screen fades in underneath. Same choreography as the team's other apps.
struct SplashScreenView: View {
    let isFinishing: Bool
    let isRevealingApp: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasEntered = false
    @State private var isFlowing = false
    @State private var isTextVisible = false

    var body: some View {
        ZStack {
            background
                .opacity(isRevealingApp ? 0 : 1)

            brand
                .opacity(isFinishing ? 0 : 1)
                .scaleEffect(isFinishing ? 1.4 : 1)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Bundle.main.appName)
        .task {
            guard !hasEntered else { return }

            if reduceMotion {
                hasEntered = true
                isTextVisible = true
                return
            }

            withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                hasEntered = true
            }

            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isFlowing = true
            }

            // A beat after the icon, so the two read as a deliberate reveal
            // rather than popping in together.
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                isTextVisible = true
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.38), value: isFinishing)
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.42), value: isRevealingApp)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.ColorToken.accent.adjustedBrightness(by: 0.12),
                    AppTheme.ColorToken.accent,
                    AppTheme.ColorToken.accent.adjustedBrightness(by: -0.16),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Slow-moving light gives the splash some life without
            // competing with the icon.
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: isFlowing ? -120 : -160, y: isFlowing ? -280 : -225)

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 64)
                .offset(x: isFlowing ? 150 : 110, y: isFlowing ? 300 : 245)
        }
    }

    private var brand: some View {
        VStack(spacing: 20) {
            // Already rounded, so it matches the launch storyboard exactly.
            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 176, height: 176)
                .shadow(color: Color(hex: 0x28185A, opacity: 0.25), radius: 24, y: 14)
                .scaleEffect(isFlowing && !reduceMotion ? 1.018 : 1)

            // Inserted into the layout (not just faded) so the stack
            // re-centres and the icon glides up as the name arrives.
            if isTextVisible {
                Text(Bundle.main.appName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
    }
}

private extension Color {
    /// Lightens (positive `delta`) or darkens (negative) by shifting HSB
    /// brightness, so the gradient stays derived from the accent.
    func adjustedBrightness(by delta: CGFloat) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: hue, saturation: saturation, brightness: min(max(brightness + delta, 0), 1), opacity: alpha)
    }
}

#Preview {
    SplashScreenView(isFinishing: false, isRevealingApp: false)
}
