import SwiftUI

/// Launch splash, picking up from the plain-colour `LaunchScreen.storyboard`.
/// The app icon builds itself: the track circle and pill pop in, the ring
/// fills to where the icon shows it, then the name arrives. A slow ambient
/// drift runs underneath, and a short exit lets the first screen fade in.
struct SplashScreenView: View {
    let isFinishing: Bool
    let isRevealingApp: Bool

    /// How long the build-up takes before the splash is ready to leave.
    /// Short: the splash is a flourish, not a wait.
    static let entranceDuration: Duration = .milliseconds(1000)

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
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.25), value: isFinishing)
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.3), value: isRevealingApp)
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

        // Starts on the very first frame, straight from the launch screen.
        // 1. The track circle and the ring filling together, the pill
        //    landing just after.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { showsMark = true }
        withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.6).delay(0.08)) {
            ringProgress = SplashMark.progress
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.1)) { showsPill = true }

        // 2. The name, as the ring lands.
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isTextVisible = true
        }
    }

    private var background: some View {
        ZStack {
            // The launch screen's exact colour, so the hand-over from the
            // storyboard has no jump.
            Color("LaunchBackground")

            // Slow-moving light gives the splash some life without
            // competing with the icon.
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: isFlowing ? -120 : -160, y: isFlowing ? -280 : -225)
                .opacity(showsMark ? 1 : 0)

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 64)
                .offset(x: isFlowing ? 150 : 110, y: isFlowing ? 300 : 245)
                .opacity(showsMark ? 1 : 0)
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

#Preview {
    SplashScreenView(isFinishing: false, isRevealingApp: false)
}
