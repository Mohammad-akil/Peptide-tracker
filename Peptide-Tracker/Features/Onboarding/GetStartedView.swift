import SwiftUI

/// The very first screen: a supply ring counting down to "5 days left",
/// medicine tiles popping in around it and a reminder chip dropping in —
/// what the app does, before a word of setup.
struct GetStartedView: View {
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ring: CGFloat = 0
    @State private var showsNumber = false
    @State private var showsTiles = false
    @State private var showsChip = false
    @State private var showsText = false
    @State private var floats = false
    @State private var pulses = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            hero
                .frame(width: 330, height: 300)

            chip
                .padding(.top, 8)

            VStack(spacing: 12) {
                Text("Know before you run out.")
                    .font(.system(size: 34, weight: .heavy))
                    .kerning(-0.8)
                    .accessibilityAddTraits(.isHeader)
                Text("Medicine reminders timed to how long your refill really takes.")
                    .font(.system(size: 17))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .opacity(showsText ? 1 : 0)
            .offset(y: showsText ? 0 : 18)

            Spacer(minLength: 16)

            Button("Get started", action: onStart)
                .buttonStyle(.primary(height: 56))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .opacity(showsText ? 1 : 0)
                .offset(y: showsText ? 0 : 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .onAppear(perform: play)
    }

    private var hero: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(AppTheme.ColorToken.accent.opacity(0.35), lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulses ? 1.5 : 0.7)
                    .opacity(pulses ? 0 : 0.55)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 3.2).repeatForever(autoreverses: false).delay(Double(index) * 1.6),
                        value: pulses
                    )
            }

            Circle()
                .fill(AppTheme.ColorToken.cardBackground)
                .frame(width: 200, height: 200)
                .shadow(color: Color(hex: 0x28185A, opacity: 0.14), radius: 30, y: 24)
            ProgressRing(progress: ring, lineWidth: 12, track: Color(light: 0xEEEBF5, dark: 0x2C2A36))
                .frame(width: 188, height: 188)

            VStack(spacing: 4) {
                Text("5")
                    .font(.system(size: 64, weight: .heavy))
                    .kerning(-2)
                Text("days left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            .scaleEffect(showsNumber ? 1 : 0.85)
            .opacity(showsNumber ? 1 : 0)

            tile(.pill, color: .blue, size: 62, angle: -10, at: CGPoint(x: -130, y: -91), delay: 0)
            tile(.syringe, color: .amber, size: 54, angle: 12, at: CGPoint(x: 130, y: -113), delay: 0.15)
            tile(.drop, color: .teal, size: 50, angle: 8, at: CGPoint(x: -126, y: 117), delay: 0.3)
            tile(.liquid, color: .pink, size: 58, angle: -8, at: CGPoint(x: 126, y: 109), delay: 0.45)
        }
        .accessibilityElement()
        .accessibilityLabel("A medicine with 5 days left")
    }

    private func tile(_ icon: AppIcon, color: MedicineColor, size: CGFloat, angle: Double, at offset: CGPoint, delay: Double) -> some View {
        Icon(icon, size: size * 0.46)
            .foregroundStyle(color.color)
            .frame(width: size, height: size)
            .background(color.color.opacity(0.13), in: .rect(cornerRadius: size * 0.3, style: .continuous))
            .rotationEffect(.degrees(angle))
            .scaleEffect(showsTiles ? 1 : 0.4)
            .opacity(showsTiles ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(reduceMotion ? 0 : 0.9 + delay), value: showsTiles)
            .offset(y: floats ? -7 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 2).repeatForever().delay(delay * 2), value: floats)
            .offset(x: offset.x, y: offset.y)
    }

    private var chip: some View {
        HStack(spacing: 8) {
            Icon(.bell, size: 14)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(AppTheme.ColorToken.accent, in: .rect(cornerRadius: 7, style: .continuous))
            Text("Time to refill Metformin")
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .opacity(showsChip ? 1 : 0)
        .offset(y: showsChip ? 0 : -14)
        .scaleEffect(showsChip ? 1 : 0.9)
    }

    private func play() {
        guard !reduceMotion else {
            ring = 0.75
            showsNumber = true; showsTiles = true; showsChip = true; showsText = true
            return
        }
        pulses = true
        withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 1.6).delay(0.3)) { ring = 0.75 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.5)) { showsNumber = true }
        showsTiles = true
        floats = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(2.0)) { showsChip = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(2.2)) { showsText = true }
    }
}

extension Bundle {
    /// The name under the app icon.
    var appName: String {
        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)?.replacingOccurrences(of: "-", with: " ")
            ?? "Refills"
    }
}

#Preview {
    GetStartedView {}
}
