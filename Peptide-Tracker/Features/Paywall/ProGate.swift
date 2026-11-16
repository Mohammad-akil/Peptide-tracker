import SwiftUI

/// The gold crown that marks a Pro-only control for free users, in place of
/// a chevron or share icon.
struct ProCrownBadge: View {
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(PaywallPalette.goldInk)
            .frame(width: size, height: size)
            .background(PaywallPalette.gold, in: .circle)
            .accessibilityLabel("Pro feature")
    }
}

/// Crown, what Pro unlocks here, and an Unlock button.
struct ProUnlockPrompt: View {
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            IllustrationView(.proUnlock, width: 170)

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Label("Unlock with Pro", systemImage: "crown.fill")
            }
            .buttonStyle(.glassPrimary)
            .frame(maxWidth: 320)
            .padding(.top, 6)
        }
        .padding(AppTheme.Spacing.mediumLarge)
    }
}

/// Free users see this section blurred with the unlock prompt over it, so
/// they can see what Pro looks like without reading the data. Pro users see
/// it as is.
private struct ProLockedModifier: ViewModifier {
    let title: String
    let message: String
    /// False shows the content to everyone (e.g. the free 7-day report).
    var isLocked = true

    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        if purchases.isPro || !isLocked {
            content
        } else {
            content
                .blur(radius: 10)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .frame(minHeight: 320, alignment: .top)
                .overlay {
                    ProUnlockPrompt(title: title, message: message) {
                        router.sheet = .paywall(reason: nil)
                    }
                    .background(AppTheme.ColorToken.cardBackground.opacity(0.94), in: .rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                    .padding(.horizontal, 4)
                }
                .clipShape(.rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
    }
}

extension View {
    /// Locks this section behind Pro for free users — see `ProLockedModifier`.
    func proLocked(_ title: String, message: String, when isLocked: Bool = true) -> some View {
        modifier(ProLockedModifier(title: title, message: message, isLocked: isLocked))
    }
}
