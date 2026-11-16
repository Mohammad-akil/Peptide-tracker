import Foundation
import Observation
import StoreKit

/// The two ways to unlock Pro — Monthly (with the free trial) or a
/// one-time Lifetime purchase — and whether the user has any of them.
///
/// Everything price-related on the paywall comes from here, straight from
/// the App Store and localized per storefront: the price, the free trial
/// (only when this Apple Account is still eligible). Nothing is hardcoded
/// except the fallback shown while the store loads, so every claim on the
/// paywall stays true (Guideline 3.1.2).
@MainActor
@Observable
final class PurchaseStore {
    enum Plan: String, CaseIterable, Identifiable {
        case monthly = "com.doseday.ios.pro.monthly"
        case lifetime = "com.doseday.ios.pro.lifetime"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly: "Monthly"
            case .lifetime: "Lifetime"
            }
        }

        /// Under the price on a plan tile.
        var period: String {
            switch self {
            case .monthly: "per month"
            case .lifetime: "once"
            }
        }

        var isSubscription: Bool { self != .lifetime }

        /// Shown until the App Store price loads.
        var fallbackPrice: String {
            switch self {
            case .monthly: "$2.99"
            case .lifetime: "$39.99"
            }
        }
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        case cancelled
        /// Ask to Buy: waiting for approval, nothing unlocked yet.
        case pending
        case failed(String)
    }

    /// Medicines a free user can track; adding past this opens the paywall.
    static let freeMedicineLimit = 2
    /// Preselected on the paywall.
    static let defaultPlan = Plan.monthly

    private(set) var products: [Plan: Product] = [:]
    /// Free-trial length per subscription, only while this Apple Account can
    /// still take it. Missing means no trial to offer, so none is promised.
    private(set) var trialDays: [Plan: Int] = [:]
    private(set) var isPro = false
    private(set) var activePlan: Plan?
    private(set) var isPurchasing = false
    var errorMessage: String?

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: Limits

    func canAddMedicine(count: Int) -> Bool {
        isPro || count < Self.freeMedicineLimit
    }

    // MARK: Paywall copy

    /// Whether the store has answered for this plan, so it can be sold.
    func isLoaded(_ plan: Plan) -> Bool { products[plan] != nil }

    func price(for plan: Plan) -> String {
        products[plan]?.displayPrice ?? plan.fallbackPrice
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
        let price = price(for: plan)
        switch plan {
        case .lifetime:
            return "\(price) one-time payment. No subscription, no renewals."
        case .monthly:
            if let days = trialDays[plan] {
                return "Free for \(days) days, then \(price) per month. Cancel anytime in Settings."
            }
            return "\(price) per month. Renews until cancelled in Settings."
        }
    }

    // MARK: Store

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: Plan.allCases.map(\.rawValue)) else { return }
        products = Dictionary(uniqueKeysWithValues: loaded.compactMap { product in
            Plan(rawValue: product.id).map { ($0, product) }
        })
        await refreshTrials()
    }

    /// Apple allows one introductory offer per subscription group, so ask
    /// StoreKit rather than assuming everyone gets the trial.
    func refreshTrials() async {
        var days: [Plan: Int] = [:]
        for plan in Plan.allCases where plan.isSubscription {
            guard let subscription = products[plan]?.subscription,
                  let offer = subscription.introductoryOffer,
                  offer.paymentMode == .freeTrial,
                  await subscription.isEligibleForIntroOffer else { continue }
            let period = offer.period
            let unitDays: Int
            switch period.unit {
            case .day: unitDays = 1
            case .week: unitDays = 7
            case .month: unitDays = 30
            case .year: unitDays = 365
            @unknown default: continue
            }
            days[plan] = period.value * unitDays * max(offer.periodCount, 1)
        }
        trialDays = days
    }

    func purchase(_ plan: Plan) async -> PurchaseOutcome {
        if products[plan] == nil { await loadProducts() }
        guard let product = products[plan] else {
            return .failed("The App Store isn’t available right now. Try again in a moment.")
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
                return isPro ? .purchased : .failed("The purchase went through but Pro didn’t unlock. Tap Restore to try again.")
            case .success(.unverified):
                return .failed("We couldn’t verify that purchase with the App Store.")
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Returns whether Pro is unlocked afterwards.
    @discardableResult
    func restore() async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        return isPro
    }

    func refreshEntitlements() async {
        var plan: Plan?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  let owned = Plan(rawValue: transaction.productID) else { continue }
            // Lifetime wins over a subscription bought before it.
            if plan != .lifetime { plan = owned }
        }
        activePlan = plan
        isPro = plan != nil
        // Having subscribed before can use up the trial.
        await refreshTrials()
    }
}
