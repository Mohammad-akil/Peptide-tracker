import StoreKit
import UIKit

/// Asks for an App Store rating at every happy moment: Pro unlocked, every
/// dose of the day taken, a weigh-in that's down (or on goal), a good
/// check-in, a refill logged, a progress card saved to Photos. The app is
/// new and ratings drive App Store search, so it asks early and often and
/// lets iOS do the rationing.
///
/// Only the system prompt is used (no custom "Enjoying Doseday?" screen
/// first): App Review rejects custom review prompts (5.6.1).
///
/// iOS decides whether the prompt actually appears (at most three times a
/// year per person, never in TestFlight), so asking more often costs
/// nothing; this only keeps asks `minimumDaysBetween` apart so the three
/// showings spread out. Never with `-sampleData` (sample data isn't their
/// success).
///
/// Never during first run either: not in onboarding, not on the paywall
/// that follows it, nowhere in the session that started with setup. App
/// Review rejects rating prompts shown before the app has been used.
@MainActor
enum ReviewPrompter {
    enum Moment {
        /// The last dose of the day was ticked off.
        case dayCompleted
        /// A refill was logged, before running out.
        case refillLogged
        /// A progress card was saved to Photos.
        case shareCardSaved
        /// Pro was bought or restored.
        case proUnlocked
        /// A weigh-in lower than the last one, or at the goal weight.
        case weightProgress
        /// Today's check-in was good or great.
        case goodCheckIn
    }

    private static let lastCompletedDayKey = "doseday.review.lastCompletedDay"
    private static let lastDateKey = "doseday.review.lastPromptDate"

    private static let minimumDaysBetween = 4.0

    /// True for the whole session that opened on onboarding (set by
    /// `RootView`), so first run never asks, the post-setup paywall included.
    static var isFirstRun = false

    /// Call when the last of a day's doses is ticked off. Counts each day
    /// once, however often its doses are unticked and ticked again.
    static func dayCompleted(_ day: Date) {
        guard !isDemo else { return }
        let defaults = UserDefaults.standard
        let key = day.startOfDay.timeIntervalSince1970
        guard defaults.double(forKey: lastCompletedDayKey) != key else { return }
        defaults.set(key, forKey: lastCompletedDayKey)
        happyMoment(.dayCompleted)
    }

    /// Asks for a rating after a short pause, if it wasn't asked recently.
    static func happyMoment(_ moment: Moment) {
        guard !isDemo, canAsk() else { return }
        Task {
            // Let the moment land first (the tick, the confetti, "Saved").
            try? await Task.sleep(for: .seconds(1.2))
            guard canAsk() else { return }
            requestNow()
        }
    }

    /// Shows the system rating prompt now, if the app is on screen (a dose
    /// ticked from a notification in the background asks nothing).
    private static func requestNow() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        AppStore.requestReview(in: scene)
        UserDefaults.standard.set(Date(), forKey: lastDateKey)
    }

    private static func canAsk() -> Bool {
        guard !isFirstRun else { return false }
        guard let last = UserDefaults.standard.object(forKey: lastDateKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= minimumDaysBetween * 86_400
    }

    private static var isDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("-sampleData")
    }
}
