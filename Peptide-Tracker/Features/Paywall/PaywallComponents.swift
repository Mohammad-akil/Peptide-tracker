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

/// One row of the Free vs Pro table.
struct PaywallFeature: Identifiable {
    enum Tier { case free, pro }

    let title: String
    let tier: Tier
    /// For a Pro row Free gets a capped version of, shown in the Free
    /// column instead of a cross (e.g. "2" medicines).
    var freeLimit: String?
    let symbol: String

    var id: String { title }
}

/// What the paywall promises. Only list what the app actually ships and
/// gates — App Review rejects paywalls that promise features the binary
/// doesn't have, and a Pro tick on something free users already get is
/// misleading. Keep this in sync with `.proLocked(...)` and the PDF
/// export gates.
@MainActor
enum PaywallContent {
    static let features: [PaywallFeature] = [
        PaywallFeature(title: "Unlimited medicines", tier: .pro, symbol: "pills.fill"),
        PaywallFeature(title: "Weekly & custom schedules", tier: .pro, symbol: "calendar"),
        PaywallFeature(title: "Adherence report & charts", tier: .pro, symbol: "chart.bar.fill"),
        PaywallFeature(title: "PDF exports for doctor visits", tier: .pro, symbol: "doc.text.fill"),
        PaywallFeature(title: "Full calculator history", tier: .pro, freeLimit: "3M", symbol: "chart.xyaxis.line"),
        PaywallFeature(title: "All 16 app icons", tier: .pro, freeLimit: "3", symbol: "app.badge"),
        PaywallFeature(title: "Dose reminders", tier: .free, symbol: "bell.fill"),
        PaywallFeature(title: "Today timeline & dose log", tier: .free, symbol: "checklist"),
        PaywallFeature(title: "Refill & supply forecast", tier: .free, symbol: "shippingbox.fill"),
        PaywallFeature(title: "Injection-site log", tier: .free, symbol: "figure.arms.open"),
    ]

    /// Lines under the headline, one at a time.
    static let highlights = [
        "Every Pro feature, on every plan.",
        "Track as many medicines as you take.",
        "See how you’re doing with adherence reports.",
        "Share clean PDFs with your doctor.",
    ]
}

// MARK: - Badge & headline

/// The purple "PRO" capsule with a crown, a gloss and a light rim.
struct PaywallProBadge: View {
    var body: some View {
        let shape = Capsule()
        HStack(spacing: 5) {
            Image(systemName: "crown.fill")
                .font(.system(size: 12, weight: .bold))
            Text(verbatim: "PRO")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .kerning(1.2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            shape
                .fill(LinearGradient(colors: [PaywallPalette.accentLight, PaywallPalette.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    shape.fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0)], startPoint: .top, endPoint: .center))
                }
                .overlay {
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
        }
        .shadow(color: PaywallPalette.accent.opacity(0.4), radius: 12, y: 6)
        .accessibilityHidden(true)
    }
}

/// "Unlock unlimited tracking" over the rotating Pro highlights, and the
/// reason the paywall opened when a free limit was hit.
struct PaywallHeadline: View {
    var reason: String?

    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            Text("Unlock \(Text("unlimited").foregroundStyle(PaywallPalette.accent)) tracking")
                .font(.system(size: 32, weight: .heavy))
                .kerning(-0.8)
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            ZStack {
                Text(PaywallContent.highlights[index])
                    .id(index)
                    .transition(.opacity)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
            .multilineTextAlignment(.center)
            // Two lines tall either way, so swapping text never moves the table.
            .lineLimit(2, reservesSpace: true)
            .frame(maxWidth: .infinity)

            if let reason {
                Text(reason)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.accentInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.ColorToken.accentSoft, in: .rect(cornerRadius: 16, style: .continuous))
                    .padding(.top, 4)
            }
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    index = (index + 1) % PaywallContent.highlights.count
                }
            }
        }
    }
}

// MARK: - Free vs Pro

/// Side-by-side Free and Pro columns, what Pro adds first, with the Pro
/// column on an accent wash so the upgrade reads at a glance.
struct PaywallComparisonTable: View {
    private let columnWidth: CGFloat = 62

    private var rows: [PaywallFeature] {
        PaywallContent.features.filter { $0.tier == .pro } + PaywallContent.features.filter { $0.tier == .free }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text("Free")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .frame(width: columnWidth)
                Text(verbatim: "PRO")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(PaywallPalette.accent)
                    .frame(width: columnWidth)
            }
            .padding(.vertical, 12)
            .accessibilityHidden(true)

            ForEach(rows) { feature in
                row(feature)
            }
        }
        .padding(.bottom, 4)
        .background(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PaywallPalette.proColumn)
                .frame(width: columnWidth)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private func row(_ feature: PaywallFeature) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: feature.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .frame(width: 24)
                Text(feature.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            freeCell(feature)
                .frame(width: columnWidth)
            included(tint: PaywallPalette.accent)
                .frame(width: columnWidth)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feature.title)
        .accessibilityValue(accessibilityValue(feature))
    }

    @ViewBuilder
    private func freeCell(_ feature: PaywallFeature) -> some View {
        if let limit = feature.freeLimit {
            Text(limit)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                .monospacedDigit()
        } else if feature.tier == .free {
            included(tint: PaywallPalette.green)
        } else {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PaywallPalette.mutedIcon)
        }
    }

    private func included(tint: Color) -> some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 19))
            .foregroundStyle(.white, tint)
    }

    private func accessibilityValue(_ feature: PaywallFeature) -> String {
        if let limit = feature.freeLimit { return "Free: \(limit). Pro: unlimited." }
        return feature.tier == .free ? "Included in Free and Pro." : "Pro only."
    }
}

// MARK: - Plans

/// Yearly (preselected) and Monthly side by side,
/// so every price is visible at once with nothing behind a dropdown.
struct PaywallPlanPicker: View {
    @Binding var selection: PurchaseStore.Plan

    private let order: [PurchaseStore.Plan] = [.yearly, .monthly]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(order) { plan in
                PaywallPlanTile(plan: plan, isSelected: plan == selection) {
                    HapticFeedback.selection()
                    selection = plan
                }
            }
        }
        // Every tile as tall as the tallest.
        .fixedSize(horizontal: false, vertical: true)
        // Room for the chips over the tiles' top edge.
        .padding(.top, 10)
        .animation(.easeInOut(duration: 0.2), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Plans")
    }
}

/// One plan as a compact tile: name, big price, period, and a green line
/// at the bottom, with one chip over the top edge — the trial on Yearly.
struct PaywallPlanTile: View {
    let plan: PurchaseStore.Plan
    let isSelected: Bool
    let action: () -> Void

    @Environment(PurchaseStore.self) private var purchases

    private var isGold: Bool { false }
    private var ring: Color { isGold ? PaywallPalette.gold : PaywallPalette.accent }
    private var isLoaded: Bool { purchases.isLoaded(plan) }

    private var chip: String? {
        switch plan {
        case .yearly: purchases.trialDays(for: plan).map { "\($0) DAYS FREE" } ?? "POPULAR"
        case .monthly: purchases.trialDays(for: plan).map { "\($0) DAYS FREE" }
        }
    }

    /// The green line at the bottom; reserves its space on every tile.
    private var highlight: String? {
        switch plan {
        case .yearly: purchases.yearlySavingsPercent.map { "SAVE \($0)%" }
        case .monthly: nil
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Button(action: action) {
            VStack(spacing: 0) {
                Text(plan.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(verbatim: purchases.price(for: plan))
                    .font(.system(size: 22, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ColorToken.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .redacted(reason: isLoaded ? [] : .placeholder)
                    .padding(.top, 4)
                Text(plan.period)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(highlight ?? " ")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(PaywallPalette.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 8)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? ring.opacity(isGold ? 0.12 : 0.1) : AppTheme.ColorToken.cardBackground, in: shape)
            .overlay(shape.strokeBorder(isSelected ? ring : AppTheme.ColorToken.separator, lineWidth: isSelected ? 2 : 1))
            .overlay(alignment: .top) {
                if let chip {
                    Text(chip)
                        .font(.system(size: 10, weight: .black))
                        .kerning(0.4)
                        .foregroundStyle(isGold ? PaywallPalette.goldInk : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isGold ? PaywallPalette.gold : PaywallPalette.accent, in: .capsule)
                        .padding(.horizontal, 4)
                        .offset(y: -10)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(plan.title), \(purchases.price(for: plan)) \(plan.period)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Purchase panel

/// The plans, reassurance line, buy button, billing disclosure and legal
/// links as one panel pinned to the bottom, so the price and terms never
/// scroll away (Guideline 3.1.2).
struct PaywallPurchasePanel: View {
    @Binding var plan: PurchaseStore.Plan
    let buy: () -> Void
    let restore: () -> Void

    @Environment(PurchaseStore.self) private var purchases

    private var callToAction: String {
        if let days = purchases.trialDays(for: plan) { return "Start \(days)-day free trial" }
        return "Continue"
    }

    var body: some View {
        VStack(spacing: 0) {
            PaywallPlanPicker(selection: $plan)
                .padding(.top, 8)

            PaywallReassuranceLine(text: plan.isSubscription ? "No commitment · Cancel anytime" : "One-time payment · No renewals")
                .padding(.top, 14)

            Button(action: buy) {
                if purchases.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(callToAction).contentTransition(.opacity)
                }
            }
            .buttonStyle(.glassPrimary)
            .disabled(purchases.isPurchasing)
            .padding(.top, 8)

            Text(purchases.disclosure(for: plan))
                .font(.system(size: 13, weight: .medium))
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
            // Fades in over content scrolling up behind the panel, then solid.
            VStack(spacing: 0) {
                LinearGradient(colors: [AppTheme.ColorToken.background.opacity(0), AppTheme.ColorToken.background], startPoint: .top, endPoint: .bottom)
                    .frame(height: 32)
                AppTheme.ColorToken.background
            }
            .padding(.top, -32)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }
}

/// A green shield and a short line, e.g. "No commitment · Cancel anytime".
struct PaywallReassuranceLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 13, weight: .bold))
            Text(text)
                .contentTransition(.opacity)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(PaywallPalette.green)
    }
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

struct PaywallBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.ColorToken.primaryText)
                .frame(width: 44, height: 44)
                .compatGlass(interactive: true, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

struct PaywallRestoreButton: View {
    let action: () -> Void

    var body: some View {
        Button("Restore", action: action)
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.ColorToken.secondaryText)
            .frame(minHeight: 44)
            .contentShape(.rect)
    }
}

// MARK: - Buying

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
