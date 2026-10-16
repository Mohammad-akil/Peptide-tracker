import Foundation
import Observation
import StoreKit

/// The two ways to unlock Pro — a monthly subscription or a one-time
/// lifetime purchase — and whether the user has either.
@MainActor
@Observable
final class PurchaseStore {
    enum Plan: String, CaseIterable, Identifiable {
        case monthly = "pro.monthly"
        case lifetime = "pro.lifetime"

        var id: String { rawValue }

        var title: String { self == .monthly ? "Monthly" : "Lifetime" }

        /// Shown until the App Store price loads.
        var fallbackPrice: String { self == .monthly ? "$3.99" : "$39.99" }
    }

    /// Medicines a free user can track; adding past this opens the paywall.
    static let freeMedicineLimit = 2

    private(set) var products: [Plan: Product] = [:]
    /// Days of the monthly plan's free trial, when this Apple Account can
    /// still take it. `nil` means no trial to offer, so none is promised.
    private(set) var monthlyTrialDays: Int?
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

    func canAddMedicine(count: Int) -> Bool {
        isPro || count < Self.freeMedicineLimit
    }

    func price(for plan: Plan) -> String {
        products[plan]?.displayPrice ?? plan.fallbackPrice
    }

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: Plan.allCases.map(\.rawValue)) else { return }
        products = Dictionary(uniqueKeysWithValues: loaded.compactMap { product in
            Plan(rawValue: product.id).map { ($0, product) }
        })
        await refreshTrial()
    }

    /// Apple only allows one introductory offer per subscription group, so
    /// ask StoreKit rather than assuming everyone gets the trial.
    func refreshTrial() async {
        guard let subscription = products[.monthly]?.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial,
              await subscription.isEligibleForIntroOffer else {
            monthlyTrialDays = nil
            return
        }
        let period = offer.period
        switch period.unit {
        case .day: monthlyTrialDays = period.value * offer.periodCount
        case .week: monthlyTrialDays = period.value * 7 * offer.periodCount
        default: monthlyTrialDays = nil
        }
    }

    /// Returns whether the plan is now unlocked.
    @discardableResult
    func purchase(_ plan: Plan) async -> Bool {
        if products[plan] == nil { await loadProducts() }
        guard let product = products[plan] else {
            errorMessage = "The App Store isn’t available right now. Try again in a moment."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .success(.unverified):
                errorMessage = "We couldn’t verify that purchase with the App Store."
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        if !isPro { errorMessage = "No earlier purchase found for this Apple Account." }
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
        await refreshTrial()
    }
}
