import SwiftUI

/// The paywall at the end of setup, laid out like the top GLP-1 apps':
/// icon, "Everything for your GLP-1 journey", a phone preview filled with
/// the user's own answers, three benefits, two plans side by side and one
/// big button. Hard: no close and no swipe-down — subscribing or restoring
/// is the way through. Price, billing terms, Restore, Terms and Privacy
/// stay on screen (Guideline 3.1.2).
struct JourneyPaywallView: View {
    let onFinish: () -> Void

    @Environment(PurchaseStore.self) private var purchases
    @Environment(MedicineStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plan = PurchaseStore.defaultPlan
    @State private var isShown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                logo
                    .padding(.top, 8)
                    .appear(isShown, delay: 0)

                Text("Everything for your GLP-1 journey")
                    .font(.system(size: 30, weight: .heavy))
                    .kerning(-0.6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .appear(isShown, delay: 0.05)

                PaywallPhonePreview(settings: store.settings, latestWeightKg: store.latestWeight?.kilograms)
                    .padding(.top, 20)
                    .appear(isShown, delay: 0.12)

                VStack(alignment: .leading, spacing: 16) {
                    benefit("syringe.fill", "Stay on top of every dose", "Track shots, pills, timing, injection sites and reminders.")
                        .appear(isShown, delay: 0.2)
                    benefit("target", "Hit your goal weight", "Log weigh-ins and watch your progress toward your goal.")
                        .appear(isShown, delay: 0.25)
                    benefit("heart.text.square.fill", "Feel better along the way", "Log side effects and share clean reports with your doctor.")
                        .appear(isShown, delay: 0.3)
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
        .background(AppTheme.ColorToken.background.ignoresSafeArea())
        .interactiveDismissDisabled()
        .task { if purchases.products.isEmpty { await purchases.loadProducts() } }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.85)) { isShown = true }
        }
    }

    // MARK: Top

    private var logo: some View {
        Image(systemName: "pill.fill")
            .font(.system(size: 22, weight: .bold))
            .rotationEffect(.degrees(-45))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(
                LinearGradient(colors: [Color(hex: 0x8A6CF0), AppTheme.ColorToken.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 13, style: .continuous)
            )
            .shadow(color: AppTheme.ColorToken.accent.opacity(0.35), radius: 10, y: 4)
            .accessibilityHidden(true)
    }

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
            // Yearly (preselected) and Monthly side by side. Lifetime stays
            // in `PurchaseStore` so earlier buyers keep Pro and can restore.
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

            Text("Your GLP-1 journey is already a lot. Tracking it shouldn’t be.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

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
        if let days = purchases.trialDays(for: plan) { return "Start my \(days)-day free trial" }
        return "Start My Journey"
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
                purchases.yearlySavingsPercent.map { "SAVE \($0)%" },
                purchases.trialDays(for: plan).map { "\($0) DAYS FREE" },
            ].compactMap { $0 }
            return parts.isEmpty ? "MOST POPULAR" : parts.joined(separator: " · ")
        case .monthly:
            return purchases.trialDays(for: plan).map { "\($0) DAYS FREE" }
        case .lifetime:
            return nil
        }
    }

    private var suffix: String {
        switch plan {
        case .monthly: "/mo"
        case .yearly: "/yr"
        case .lifetime: ""
        }
    }

    private var detail: String {
        switch plan {
        case .yearly:
            if let perMonth = purchases.yearlyPerMonth { return "Just \(perMonth)/mo, billed yearly" }
            return "Billed yearly · Cancel anytime"
        case .monthly: return "Billed monthly"
        case .lifetime: return "Pay once, keep it forever"
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

/// A small, live mock of the app inside a phone outline, filled with what
/// the user told setup: their medication and dose, schedule and goal. It
/// fades out at the bottom like a cropped screenshot.
private struct PaywallPhonePreview: View {
    let settings: AppSettings

    @State private var level: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var medication: String {
        guard let medication = settings.glp1Medication, medication != .dontKnow else { return "GLP-1" }
        let typed = settings.glp1OtherMedication
        return medication == .other ? (typed.isEmpty ? "GLP-1" : typed) : medication.title
    }

    private var dose: String { settings.glp1Dose.isEmpty ? "0.5 mg" : settings.glp1Dose }

    private var schedule: String {
        switch settings.glp1IntervalDays {
        case 1: "Every day"
        case let days?: "Every \(days) days"
        case nil: "Weekly"
        }
    }

    private var weight: String?

    init(settings: AppSettings, latestWeightKg: Double?) {
        self.settings = settings
        self.weight = latestWeightKg.map { settings.weightUnit.format($0) }
    }

    private var goal: String? {
        settings.goalWeightKg.map { settings.weightUnit.format($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Doseday").font(.system(size: 13, weight: .heavy))
                Spacer()
                Text("Today")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.ColorToken.accentSoft, in: .capsule)
                    .foregroundStyle(AppTheme.ColorToken.accent)
            }

            // Medication level card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.heart.fill").font(.system(size: 10, weight: .bold))
                    Text("Medication level").font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Text(medication)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(AppTheme.ColorToken.accent, lineWidth: 1.2))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
                .foregroundStyle(AppTheme.ColorToken.secondaryText)
                Text(dose).font(.system(size: 20, weight: .heavy)).monospacedDigit()
                LevelCurve()
                    .trim(from: 0, to: level)
                    .stroke(AppTheme.ColorToken.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(height: 30)
            }
            .padding(10)
            .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 12, style: .continuous))

            HStack(spacing: 8) {
                miniCard("calendar", "Next dose", schedule, tint: Color(hex: 0x30B0C7))
                miniCard("target", "Goal", goal ?? "Set a goal", tint: Color(hex: 0xFF9F0A))
            }
            HStack(spacing: 8) {
                miniCard("figure.arms.open", "Next site", "Left thigh", tint: Color(hex: 0x34C759))
                miniCard("scalemass.fill", "Weight", weight ?? "Log a weigh-in", tint: Color(hex: 0x0A84FF))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .frame(width: 230, height: 250, alignment: .top)
        .background(AppTheme.ColorToken.background)
        .clipShape(.rect(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
        .overlay {
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                .strokeBorder(AppTheme.ColorToken.primaryText.opacity(0.85), lineWidth: 5)
        }
        .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of Doseday showing your \(medication) dose, schedule and goal.")
        .onAppear {
            if reduceMotion { level = 1 } else {
                withAnimation(.easeInOut(duration: 1.4).delay(0.5)) { level = 1 }
            }
        }
    }

    private func miniCard(_ symbol: String, _ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 9, weight: .bold)).foregroundStyle(tint)
                Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(AppTheme.ColorToken.secondaryText)
            }
            Text(value).font(.system(size: 12, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.cardBackground, in: .rect(cornerRadius: 10, style: .continuous))
    }
}

/// A dose-level line: rises after each dose, eases off, rises again.
private struct LevelCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let peaks = 3
        let step = rect.width / CGFloat(peaks)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.85))
        for i in 0..<peaks {
            let x0 = rect.minX + CGFloat(i) * step
            let peakY = rect.minY + rect.height * (0.35 - CGFloat(i) * 0.12)
            path.addCurve(
                to: CGPoint(x: x0 + step, y: rect.maxY * (0.75 - CGFloat(i) * 0.12)),
                control1: CGPoint(x: x0 + step * 0.15, y: peakY),
                control2: CGPoint(x: x0 + step * 0.45, y: peakY)
            )
        }
        return path
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
