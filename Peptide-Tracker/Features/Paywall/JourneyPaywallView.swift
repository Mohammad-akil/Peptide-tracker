import SwiftUI

/// The paywall at the end of setup, laid out like the top GLP-1 apps':
/// "Everything for your GLP-1 journey", a phone showing a real
/// screenshot of the app, three benefits, two plans side by side and one
/// big button. Hard: no close and no swipe-down — subscribing or restoring
/// is the way through. Price, billing terms, Restore, Terms and Privacy
/// stay on screen (Guideline 3.1.2).
struct JourneyPaywallView: View {
    let onFinish: () -> Void

    @Environment(PurchaseStore.self) private var purchases
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plan = PurchaseStore.defaultPlan
    @State private var isShown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Everything for your GLP-1 journey")
                    .font(.system(size: 30, weight: .heavy))
                    .kerning(-0.6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 24)
                    .appear(isShown, delay: 0)

                PaywallPhonePreview()
                    .padding(.top, 20)
                    .appear(isShown, delay: 0.12)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(Self.benefits.enumerated()), id: \.offset) { index, item in
                        benefit(item.symbol, item.title, item.detail)
                            .appear(isShown, delay: 0.2 + min(Double(index), 6) * 0.05)
                    }
                }
                .padding(.top, 22)
            }
            .padding(.horizontal, AppTheme.Spacing.mediumLarge)
            .padding(.bottom, 16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) { purchasePanel }
        #if DEBUG
        // Debug builds only: a way past the hard paywall while developing.
        // It comes back on the next launch, like it would for a real user.
        .overlay(alignment: .topTrailing) {
            PaywallCloseButton(action: onFinish)
                .padding(.trailing, 12)
                .padding(.top, 4)
        }
        #endif
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .interactiveDismissDisabled()
        .task { if purchases.products.isEmpty { await purchases.loadProducts() } }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.85)) { isShown = true }
        }
    }

    // MARK: Top

    /// What Pro unlocks, in the order people care about.
    private static let benefits: [(symbol: String, title: String, detail: String)] = [
        ("syringe.fill", String(localized: "Stay on top of every dose"), String(localized: "Reminders for shots and pills, right on time.")),
        ("figure.arms.open", String(localized: "Rotate injection sites"), String(localized: "See where you injected last and where to go next.")),
        ("target", String(localized: "Hit your goal weight"), String(localized: "Log weigh-ins and watch your progress toward your goal.")),
        ("shippingbox.fill", String(localized: "Never run out"), String(localized: "Supply countdowns and refill alerts before you’re low.")),
        ("face.smiling.inverse", String(localized: "Daily check-ins"), String(localized: "Track mood, energy and side effects day by day.")),
        ("chart.bar.xaxis", String(localized: "Insights and calendar"), String(localized: "See your adherence and trends over 7, 30 and 90 days.")),
        ("doc.text.fill", String(localized: "Doctor-ready reports"), String(localized: "Share clean PDF reports and export your data anytime.")),
        ("function", String(localized: "Health calculators"), String(localized: "BMI, daily calories and macros in seconds.")),
        ("square.grid.2x2.fill", String(localized: "Home Screen widgets"), String(localized: "Your next dose and supply at a glance.")),
        ("lock.shield.fill", String(localized: "Private by design"), String(localized: "Privacy mode hides medicine names on your screen.")),
    ]

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold))
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Plans

    private var purchasePanel: some View {
        VStack(spacing: 0) {
            // Yearly (preselected) and Monthly side by side, from the
            // current RevenueCat Offering.
            HStack(spacing: 10) {
                JourneyPlanTile(plan: .yearly, isSelected: plan == .yearly) { select(.yearly) }
                JourneyPlanTile(plan: .monthly, isSelected: plan == .monthly) { select(.monthly) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 16)

            Button(action: buy) {
                if purchases.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(callToAction).contentTransition(.opacity)
                }
            }
            .buttonStyle(.glassPrimary)
            .disabled(purchases.isPurchasing)
            .padding(.top, 12)

            Text(purchases.disclosure(for: plan))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .padding(.top, 8)

            PaywallLegalLinks(onRestore: restore)
        }
        .padding(.horizontal, AppTheme.Spacing.mediumLarge)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: plan)
        .background(alignment: .top) {
            VStack(spacing: 0) {
                LinearGradient(colors: [AppTheme.ColorToken.background.opacity(0), AppTheme.ColorToken.background], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
                AppTheme.ColorToken.background
            }
            .padding(.top, -28)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    private var callToAction: String {
        if let days = purchases.trialDays(for: plan) { return String(localized: "Start my \(days)-day free trial") }
        return String(localized: "Start My Journey")
    }

    private func select(_ newPlan: PurchaseStore.Plan) {
        guard plan != newPlan else { return }
        HapticFeedback.selection()
        plan = newPlan
    }

    private func buy() {
        Task {
            if await PaywallActions.buy(plan, purchases: purchases, router: router) { onFinish() }
        }
    }

    private func restore() {
        Task {
            if await PaywallActions.restore(purchases: purchases, router: router) { onFinish() }
        }
    }
}

// MARK: - Plan tile

/// One plan: its name and a radio, the price, and a line under it. Yearly
/// carries the savings / trial badge. Every number comes from the App Store, so the badge only says
/// what's true for this account and storefront.
private struct JourneyPlanTile: View {
    let plan: PurchaseStore.Plan
    let isSelected: Bool
    let action: () -> Void

    @Environment(PurchaseStore.self) private var purchases

    private var isFeatured: Bool { plan == .yearly }

    private var badge: String? {
        switch plan {
        case .yearly:
            let parts = [
                purchases.yearlySavingsPercent.map { String(localized: "SAVE \($0)%") },
                purchases.trialDays(for: plan).map { String(localized: "\($0) DAYS FREE") },
            ].compactMap { $0 }
            return parts.isEmpty ? String(localized: "MOST POPULAR") : parts.joined(separator: " · ")
        case .monthly:
            return purchases.trialDays(for: plan).map { String(localized: "\($0) DAYS FREE") }
        }
    }

    private var suffix: String {
        switch plan {
        case .monthly: "/mo"
        case .yearly: "/yr"
        }
    }

    private var detail: String {
        switch plan {
        case .yearly:
            if let perMonth = purchases.yearlyPerMonth { return String(localized: "Just \(perMonth)/mo, billed yearly") }
            return String(localized: "Billed yearly · Cancel anytime")
        case .monthly: return String(localized: "Billed monthly")
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: action) {
            content
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(isSelected ? AppTheme.ColorToken.accentSoft : AppTheme.ColorToken.cardBackground, in: shape)
                .overlay(shape.strokeBorder(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.separator, lineWidth: isSelected ? 2 : 1))
                .overlay(alignment: .top) {
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .black))
                            .kerning(0.4)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(isFeatured ? AppTheme.ColorToken.accent : Color.black, in: .capsule)
                            .padding(.horizontal, 6)
                            .offset(y: -9)
                    }
                }
                .scaleEffect(isSelected ? 1 : 0.98)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plan.title), \(purchases.price(for: plan)) \(plan.period). \(detail)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                title
                Spacer(minLength: 4)
                RadioMark(isSelected: isSelected, size: 20)
            }
            price(size: 22)
            detailText
            Spacer(minLength: 0)
        }
    }

    private var title: some View {
        Text(plan.title.uppercased())
            .font(.system(size: 13, weight: .heavy))
            .kerning(0.3)
    }

    private var detailText: some View {
        Text(detail)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func price(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(verbatim: purchases.price(for: plan))
                .font(.system(size: size, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.primaryText)
                .redacted(reason: purchases.isLoaded(plan) ? [] : .placeholder)
            Text(suffix)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

// MARK: - Phone preview

/// A real screenshot of the app (Today, with the tab bar) inside a phone
/// outline, cropped and faded at the bottom.
private struct PaywallPhonePreview: View {
    private let width: CGFloat = 230

    var body: some View {
        Image("paywall-app-preview")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: 270, alignment: .top)
            .clipShape(.rect(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
            .overlay {
                UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                    .strokeBorder(AppTheme.ColorToken.primaryText.opacity(0.85), lineWidth: 5)
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview of Doseday's Today screen with your doses and refills.")
    }
}

private extension View {
    /// Fades and lifts in once `isShown` turns on, `delay` seconds later.
    func appear(_ isShown: Bool, delay: Double) -> some View {
        opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : 14)
            .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(delay), value: isShown)
    }
}
