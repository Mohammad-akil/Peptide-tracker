import Foundation
import Observation
import RevenueCat

/// Doseday Pro through RevenueCat: the plans the paywall offers, their
/// prices and free trial, buying and restoring, and whether this user is
/// Pro (the `dosedaypro` entitlement).
///
/// The plans come from RevenueCat's *current Offering* (its Annual and
/// Monthly packages), so prices and products can change from the
/// dashboard without an app update. Every price is the App Store's own,
/// localized per storefront; nothing is hardcoded, so every claim on the
/// paywall stays true (Guideline 3.1.2).
@MainActor
@Observable
final class PurchaseStore {
    enum Plan: String, CaseIterable, Identifiable {
        case monthly = "com.doseday.ios.pro.monthly"
        case yearly = "com.doseday.ios.pro.yearly"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly: "Monthly"
            case .yearly: "Yearly"
            }
        }

        /// Under the price on a plan tile.
        var period: String {
            switch self {
            case .monthly: "per month"
            case .yearly: "per year"
            }
        }

        var isSubscription: Bool { true }
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        case cancelled
        /// Ask to Buy: waiting for approval, nothing unlocked yet.
        case pending
        case failed(String)
    }

    /// The RevenueCat entitlement that unlocks the app.
    static let entitlementID = "dosedaypro"
    /// Preselected on the paywall.
    static let defaultPlan = Plan.yearly
    /// Sized like a price, shown redacted until the real one loads.
    private static let pricePlaceholder = "$00.00"

    /// The current Offering's packages, by plan.
    private(set) var packages: [Plan: Package] = [:]
    /// Free-trial length per plan, only while this Apple Account can still
    /// take it. Missing means no trial to offer, so none is promised.
    private(set) var trialDays: [Plan: Int] = [:]
    private(set) var isPro = false
    /// False until RevenueCat first answers, so the hard paywall never
    /// flashes over someone who has already paid.
    private(set) var hasCheckedEntitlements = false
    private(set) var activePlan: Plan?
    private(set) var isPurchasing = false
    var errorMessage: String?

    /// The store products behind the packages, by plan.
    var products: [Plan: StoreProduct] { packages.mapValues(\.storeProduct) }

    private var updates: Task<Void, Never>?

    init() {}

    /// Sets up RevenueCat and starts listening. Called just after launch
    /// draws its first frame, so configuring never holds up the splash.
    func start() {
        guard updates == nil, !hasCheckedEntitlements else { return }
        guard Self.configureIfNeeded() else {
            // No key (or a SwiftUI preview): nothing to sell, nobody is Pro.
            hasCheckedEntitlements = true
            return
        }
        updates = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    /// Configures RevenueCat once with the public key from Info.plist
    /// (`REVENUECAT_API_KEY` in Config/Secrets.xcconfig). Returns whether
    /// RevenueCat is ready.
    private static func configureIfNeeded() -> Bool {
        if Purchases.isConfigured { return true }
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return false }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              key.hasPrefix("appl_") else {
            #if DEBUG
            print("⚠️ RevenueCat: no API key. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig and add the appl_ key.")
            #endif
            return false
        }
        #if DEBUG
        // `.debug` floods the console and slows launch under Xcode.
        Purchases.logLevel = .info
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: key)
        return true
    }

    // MARK: Paywall copy

    /// Whether the store has answered for this plan, so it can be sold.
    func isLoaded(_ plan: Plan) -> Bool { packages[plan] != nil }

    /// Yearly as a monthly price, "$2.49", in the store's currency. Nil
    /// until Yearly has loaded.
    var yearlyPerMonth: String? {
        products[.yearly]?.localizedPricePerMonth
    }

    /// How much Yearly saves over twelve months of Monthly, as a whole
    /// percentage. Nil until both have loaded or when there's no saving,
    /// so the badge only ever shows a true number.
    var yearlySavingsPercent: Int? {
        guard let yearly = products[.yearly]?.price, let monthly = products[.monthly]?.price, monthly > 0 else { return nil }
        let fullYear = monthly * 12
        guard yearly < fullYear else { return nil }
        let percent = NSDecimalNumber(decimal: (fullYear - yearly) / fullYear * 100).doubleValue
        return Int(percent.rounded(.down))
    }

    /// The App Store price from RevenueCat, or a placeholder (always shown
    /// redacted) while it loads.
    func price(for plan: Plan) -> String {
        products[plan]?.localizedPriceString ?? Self.pricePlaceholder
    }

    func trialDays(for plan: Plan) -> Int? { trialDays[plan] }

    /// The longest trial on offer, for "Try Pro free for 7 days".
    var bestTrial: (plan: Plan, days: Int)? {
        Plan.allCases
            .compactMap { plan -> (plan: Plan, days: Int)? in trialDays[plan].map { (plan: plan, days: $0) } }
            .max { $0.days < $1.days }
    }

    /// What they'll pay and when, said plainly under the buy button.
    func disclosure(for plan: Plan) -> String {
        guard isLoaded(plan) else { return "Loading prices from the App Store…" }
        let price = price(for: plan)
        let period = plan == .yearly ? "year" : "month"
        if let days = trialDays[plan] {
            return "Free for \(days) days, then \(price) per \(period). Cancel anytime in Settings."
        }
        return "\(price) per \(period). Renews until cancelled in Settings."
    }

    // MARK: Store

    /// Reads the current Offering's Annual and Monthly packages.
    func loadProducts() async {
        guard Purchases.isConfigured,
              let offering = try? await Purchases.shared.offerings().current else { return }
        var loaded: [Plan: Package] = [:]
        if let annual = offering.annual { loaded[.yearly] = annual }
        if let monthly = offering.monthly { loaded[.monthly] = monthly }
        // Fall back to matching product IDs if the packages use custom types.
        for package in offering.availablePackages {
            if let plan = Plan(rawValue: package.storeProduct.productIdentifier), loaded[plan] == nil {
                loaded[plan] = package
            }
        }
        packages = loaded
        await refreshTrials()
    }

    /// Apple allows one introductory offer per subscription group, so ask
    /// rather than assuming everyone gets the trial.
    func refreshTrials() async {
        guard Purchases.isConfigured else { return }
        var days: [Plan: Int] = [:]
        for (plan, product) in products {
            guard let offer = product.introductoryDiscount, offer.paymentMode == .freeTrial,
                  await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product) == .eligible
            else { continue }
            let period = offer.subscriptionPeriod
            let unitDays: Int
            switch period.unit {
            case .day: unitDays = 1
            case .week: unitDays = 7
            case .month: unitDays = 30
            case .year: unitDays = 365
            @unknown default: continue
            }
            days[plan] = period.value * unitDays * max(offer.numberOfPeriods, 1)
        }
        trialDays = days
    }

    func purchase(_ plan: Plan) async -> PurchaseOutcome {
        guard Purchases.isConfigured else {
            return .failed("Purchases aren’t set up in this build.")
        }
        if packages[plan] == nil { await loadProducts() }
        guard let package = packages[plan] else {
            return .failed("The App Store isn’t available right now. Try again in a moment.")
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)
            return isPro ? .purchased : .failed("The purchase went through but Pro didn’t unlock. Tap Restore to try again.")
        } catch {
            if (error as NSError).code == ErrorCode.paymentPendingError.rawValue { return .pending }
            if (error as NSError).code == ErrorCode.purchaseCancelledError.rawValue { return .cancelled }
            return .failed(error.localizedDescription)
        }
    }

    /// Returns whether Pro is unlocked afterwards.
    @discardableResult
    func restore() async -> Bool {
        guard Purchases.isConfigured else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        if let info = try? await Purchases.shared.restorePurchases() { apply(info) }
        return isPro
    }

    func refreshEntitlements() async {
        guard Purchases.isConfigured else {
            hasCheckedEntitlements = true
            return
        }
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        } else {
            // Offline with nothing cached: decide anyway, so the app isn't
            // stuck waiting; the stream unlocks Pro once RevenueCat answers.
            hasCheckedEntitlements = true
        }
        // Having subscribed before can use up the trial.
        await refreshTrials()
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Self.entitlementID]
        isPro = entitlement?.isActive == true
        activePlan = isPro ? entitlement.flatMap { Plan(rawValue: $0.productIdentifier) } : nil
        hasCheckedEntitlements = true
    }
}
