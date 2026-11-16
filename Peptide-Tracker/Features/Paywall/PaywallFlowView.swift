import SwiftUI

/// The 3-step paywall shown once after setup: an intro with the app
/// preview, how the free trial works day by day (only when this Apple
/// Account can get one), then `PaywallView` with the plans. Close is
/// always one tap away on every step — the app works without Pro.
struct PaywallFlowView: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.intro
    @State private var isMovingForward = true

    enum Step: Int, Comparable {
        case intro, trial, plans
        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private var trial: (plan: PurchaseStore.Plan, days: Int)? { purchases.bestTrial }

    var body: some View {
        ZStack {
            page
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: isMovingForward ? .leading : .trailing).combined(with: .opacity)
                ))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .intro:
            stepPage(
                topLeading: AnyView(PaywallRestoreButton(action: restore)),
                button: trial != nil ? "See how the free trial works" : "See plans",
                footer: "Reminders and your dose log stay free"
            ) {
                PaywallIntroPage()
            }
        case .trial:
            if let trial {
                stepPage(
                    topLeading: AnyView(PaywallBackButton { go(to: .intro) }),
                    button: "See plans",
                    footer: nil
                ) {
                    PaywallTrialPage(plan: trial.plan, days: trial.days)
                }
            }
        case .plans:
            PaywallView(onBack: { go(to: trial != nil ? .trial : .intro) }, onFinish: { dismiss() })
        }
    }

    /// One step with the shared top bar (its leading control, close) and
    /// the bottom button that moves on.
    private func stepPage<Content: View>(topLeading: AnyView, button: String, footer: String?, @ViewBuilder content: () -> Content) -> some View {
        content()
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 0) {
                    topLeading
                    Spacer(minLength: 0)
                    PaywallCloseButton { dismiss() }
                }
                .frame(height: 44)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Button(button) { go(to: step == .intro && trial != nil ? .trial : .plans) }
                        .buttonStyle(.glassPrimary)
                    if let footer {
                        Label(footer, systemImage: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.ColorToken.secondaryText)
                            .labelStyle(PaywallFooterLabelStyle())
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.mediumLarge)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
    }

    private func go(to newStep: Step) {
        HapticFeedback.selection()
        isMovingForward = newStep > step
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            step = newStep
        }
    }

    private func restore() {
        Task {
            if await PaywallActions.restore(purchases: purchases, router: router) { dismiss() }
        }
    }
}

/// A green tick before the text.
private struct PaywallFooterLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(PaywallPalette.green)
            configuration.title
        }
    }
}

#Preview {
    PaywallFlowView()
        .environment(PurchaseStore())
        .environment(AppRouter())
}
