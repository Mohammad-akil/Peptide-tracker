import SwiftUI
import UIKit

/// Launch splash, picking up from the plain-colour `LaunchScreen.storyboard`.
/// The app icon builds itself: the track circle and pill pop in, the ring
/// fills to where the icon shows it, then the name arrives. A slow ambient
/// drift runs underneath, and a short exit lets the first screen fade in.
struct SplashScreenView: View {
    let isFinishing: Bool
    let isRevealingApp: Bool

    /// How long the build-up takes before the splash is ready to leave.
    static let entranceDuration: Duration = .milliseconds(2000)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false
    @State private var showsMark = false
    @State private var showsPill = false
    @State private var ringProgress: CGFloat = 0
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
        .task { await play() }
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.38), value: isFinishing)
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.42), value: isRevealingApp)
    }

    private func play() async {
        guard !hasStarted else { return }
        hasStarted = true

        if reduceMotion {
            showsMark = true
            showsPill = true
            ringProgress = SplashMark.progress
            isTextVisible = true
            return
        }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            isFlowing = true
        }

        // 1. The track circle, then the pill a beat later.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { showsMark = true }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) { showsPill = true }

        // 2. The ring fills clockwise from the top.
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.9)) {
            ringProgress = SplashMark.progress
        }

        // 3. The name, once the ring has landed.
        try? await Task.sleep(for: .milliseconds(850))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            isTextVisible = true
        }
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
        VStack(spacing: 24) {
            SplashMark(showsMark: showsMark, showsPill: showsPill, ringProgress: ringProgress)
                .scaleEffect(isFlowing && !reduceMotion ? 1.018 : 1)

            // Inserted into the layout (not just faded) so the stack
            // re-centres and the mark glides up as the name arrives.
            if isTextVisible {
                Text(Bundle.main.appName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
    }
}

/// The app icon's ring and pill, drawn so each part can animate. Proportions
/// follow the 1024px icon artwork.
private struct SplashMark: View {
    let showsMark: Bool
    let showsPill: Bool
    let ringProgress: CGFloat

    /// How far round the icon's ring is filled.
    static let progress: CGFloat = 0.73

    private let size: CGFloat = 132
    private var lineWidth: CGFloat { size * 0.11 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.28), lineWidth: lineWidth)
                .scaleEffect(showsMark ? 1 : 0.6)
                .opacity(showsMark ? 1 : 0)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(ringProgress > 0 ? 1 : 0)

            pill
                .scaleEffect(showsPill ? 1 : 0.3)
                .rotationEffect(.degrees(showsPill ? -45 : -135))
                .opacity(showsPill ? 1 : 0)
        }
        .frame(width: size, height: size)
    }

    /// White half lower-left, lavender half upper-right, as on the icon.
    private var pill: some View {
        HStack(spacing: 0) {
            Color.white
            Color(hex: 0xD9CFF8)
        }
        .frame(width: size * 0.52, height: size * 0.21)
        .clipShape(.capsule)
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
