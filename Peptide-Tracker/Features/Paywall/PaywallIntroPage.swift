import SwiftUI

/// Paywall step 1: a phone playing the app preview, two floating chips
/// showing what the app does, and the pitch. Plain claims only — no
/// ratings, awards or "loved by" lines the app can't back up.
struct PaywallIntroPage: View {
    var body: some View {
        VStack(spacing: 0) {
            showcase
                .frame(maxHeight: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 18)
            pitch
                .padding(.bottom, 8)
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .background(alignment: .top) {
            RadialGradient(
                colors: [PaywallPalette.accent.opacity(0.30), PaywallPalette.accent.opacity(0.08), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 230
            )
            .frame(width: 420, height: 460)
            .offset(y: 30)
            .allowsHitTesting(false)
        }
    }

    // MARK: Phone

    private var showcase: some View {
        phone
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                chip(symbol: "checkmark", tint: PaywallPalette.green, caption: "Morning dose", title: "Taken")
                    .offset(x: -8, y: 64)
            }
            .overlay(alignment: .bottomTrailing) {
                chip(symbol: "shippingbox.fill", tint: PaywallPalette.accent, caption: "Supply", title: "Refill in 6 days")
                    .offset(x: 8, y: -56)
            }
    }

    private var phone: some View {
        let outer = RoundedRectangle(cornerRadius: 36, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: 30, style: .continuous)

        return ZStack {
            LoopingVideo(name: "onboarding-1", isPlaying: true) {
                AppTheme.ColorToken.cardBackground
            }
            VStack {
                Capsule()
                    .fill(.black)
                    .frame(width: 58, height: 17)
                    .padding(.top, 9)
                Spacer()
            }
        }
        .background(AppTheme.ColorToken.cardBackground)
        .clipShape(inner)
        .padding(6)
        .background(
            LinearGradient(colors: [Color(hex: 0x2A2733), Color(hex: 0x121018), Color(hex: 0x24212E)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: outer
        )
        .overlay(outer.strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: PaywallPalette.accent.opacity(0.22), radius: 24)
        .shadow(color: .black.opacity(0.35), radius: 28, y: 26)
        .aspectRatio(188.0 / 404.0, contentMode: .fit)
        .frame(maxHeight: 404)
        .accessibilityHidden(true)
    }

    private func chip(symbol: String, tint: Color, caption: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint, in: .rect(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(caption)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
            }
        }
        .padding(.vertical, 10)
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .background(AppTheme.ColorToken.cardBackground.opacity(0.92), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppTheme.ColorToken.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 14)
        .accessibilityHidden(true)
    }

    // MARK: Pitch

    private var pitch: some View {
        VStack(spacing: 12) {
            PaywallProBadge()
            Text("Never miss a dose.\n\(Text("Never run out.").foregroundStyle(PaywallPalette.accent))")
                .font(.system(size: 32, weight: .heavy))
                .kerning(-0.8)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text("Pro tracks every medicine you take, shows how you’re doing, and makes doctor visits easier.")
                .font(.system(size: 15.5, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .lineSpacing(2)
                .frame(maxWidth: 330)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}
