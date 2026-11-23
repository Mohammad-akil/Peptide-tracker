import SwiftUI

// MARK: - Palette & content

/// The few colours the paywall adds to `AppTheme`: gold for Lifetime and
/// the Pro crown, green for "included" and reassurance, orange for the
/// trial reminder. The accent stays the app's one purple.
enum PaywallPalette {
    static let accent = AppTheme.ColorToken.accent
    static let accentLight = Color(hex: 0x8A6CF0)
    static let gold = Color(light: 0xE8AE2A, dark: 0xF5C451)
    static let goldInk = Color(hex: 0x2A1C00)
    static let green = Color(light: 0x0F9F74, dark: 0x34D399)
    static let orange = Color(light: 0xE8690B, dark: 0xFB923C)
    static let mutedIcon = Color(light: 0xA3A8B5, dark: 0x5A5866)
    /// The Pro column's wash in the comparison table.
    static let proColumn = Color(uiColor: UIColor { traits in
        UIColor(hex: 0x6A45D8).withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.24 : 0.09)
    })
}

/// Terms of Use · Restore · Privacy Policy — required on the purchase
/// screen (Guideline 3.1.2).
struct PaywallLegalLinks: View {
    var onRestore: (() -> Void)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 10) {
            Button("Terms of Use") { openURL(AppLinks.termsOfUse) }
            separator
            if let onRestore {
                Button("Restore", action: onRestore)
                separator
            }
            Button("Privacy Policy") { openURL(AppLinks.privacyPolicy) }
        }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(AppTheme.ColorToken.secondaryText)
        .frame(minHeight: 40)
    }

    private var separator: some View {
        Text("·")
            .foregroundStyle(PaywallPalette.mutedIcon)
            .accessibilityHidden(true)
    }
}

// MARK: - Top bar buttons

struct PaywallCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(.x, size: 16)
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .frame(width: 36, height: 36)
                .background(AppTheme.ColorToken.controlFill, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

/// Buy and Restore with the app's toasts, shared by every paywall screen.
@MainActor
enum PaywallActions {
    /// Returns whether Pro is now unlocked.
    static func buy(_ plan: PurchaseStore.Plan, purchases: PurchaseStore, router: AppRouter) async -> Bool {
        guard !purchases.isPurchasing else { return false }
        // Read before buying: the trial is used up once it starts.
        let trialDays = purchases.trialDays(for: plan)
        let price = purchases.price(for: plan)
        router.show(.loading("Contacting the App Store…"))
        switch await purchases.purchase(plan) {
        case .purchased:
            router.show(.success("Welcome to Pro", message: "Everything’s unlocked. Thank you!"))
            router.celebrate()
            if let trialDays {
                await TrialReminder.schedule(trialDays: trialDays, price: price, period: plan.period)
            }
            return true
        case .pending:
            router.show(.info("Waiting for approval", message: "Pro unlocks as soon as the purchase is approved."))
        case .cancelled:
            router.dismissToast()
        case .failed(let message):
            router.show(.error("Purchase didn’t go through", message: message))
        }
        return false
    }

    /// Returns whether Pro is now unlocked.
    static func restore(purchases: PurchaseStore, router: AppRouter) async -> Bool {
        guard !purchases.isPurchasing else { return false }
        router.show(.loading("Checking your purchases…"))
        if await purchases.restore() {
            router.show(.success("Pro restored", message: "Welcome back."))
            router.celebrate()
            return true
        }
        router.show(.warning("No earlier purchase found", message: "Nothing to restore for this Apple Account."))
        return false
    }
}
