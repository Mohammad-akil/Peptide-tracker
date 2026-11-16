import SwiftUI

/// The paywall opened from anywhere a free user reaches Pro (the medicine
/// limit, the report, PDF exports, Settings), and the last step of
/// `PaywallFlowView`. The headline and Free vs Pro table scroll; the plans,
/// buy button, billing terms and legal links are one panel pinned to the
/// bottom, so the price and terms never scroll away (Guideline 3.1.2).
struct PaywallView: View {
    /// Why it opened, when a free limit was hit.
    var reason: String?
    /// Shows a back button — set when this is the flow's last step.
    var onBack: (() -> Void)?
    /// Runs on close or once Pro unlocks. Defaults to dismissing.
    var onFinish: (() -> Void)?

    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var plan = PurchaseStore.defaultPlan

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PaywallProBadge()
                PaywallHeadline(reason: reason)
                    .padding(.top, 12)
                PaywallComparisonTable()
                    .padding(.top, 12)
            }
            .padding(.horizontal, AppTheme.Spacing.mediumLarge)
            .padding(.top, 4)
            .padding(.bottom, AppTheme.Spacing.medium)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 0) {
                if let onBack { PaywallBackButton(action: onBack) }
                Spacer(minLength: 0)
                PaywallCloseButton(action: finish)
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PaywallPurchasePanel(plan: $plan, buy: buy, restore: restore)
        }
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        // Retries if the launch fetch failed (e.g. offline at launch).
        .task { if purchases.products.isEmpty { await purchases.loadProducts() } }
    }

    private func finish() {
        if let onFinish { onFinish() } else { dismiss() }
    }

    private func buy() {
        Task {
            if await PaywallActions.buy(plan, purchases: purchases, router: router) { finish() }
        }
    }

    private func restore() {
        Task {
            if await PaywallActions.restore(purchases: purchases, router: router) { finish() }
        }
    }
}

#Preview {
    PaywallView(reason: "You’re tracking 2 medicines, the free limit. Go Pro to add more.")
        .environment(PurchaseStore())
        .environment(AppRouter())
}
