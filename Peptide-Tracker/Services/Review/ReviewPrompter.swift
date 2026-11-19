import StoreKit
import UIKit

/// Asks for an App Store rating at a happy moment: every dose of the day
/// taken, a refill logged, a progress card saved to Photos. Only once the
/// person clearly uses the app: a few days with every dose taken, or a
/// week since they started with a medicine added. Ported from Plates'
/// `ReviewPrompter`.
///
/// Only the system prompt is used (no custom "Enjoying Doseday?" screen
/// first): App Review rejects custom review prompts (5.6.1).
///
/// iOS decides whether the prompt actually appears (at most three times a
/// year), so this only picks the moment and keeps from asking too often:
/// at most once per app version, and never within `minimumDaysBetween` of
/// the last ask. Never with `-sampleData` (sample data isn't their success).
@MainActor
enum ReviewPrompter {
    enum Moment {
        /// The last dose of the day was ticked off.
        case dayCompleted
        /// A refill was logged, before running out.
        case refillLogged
        /// A progress card was saved to Photos.
        case shareCardSaved
    }

    private static let completedDaysKey = "doseday.review.completedDays"
    private static let lastCompletedDayKey = "doseday.review.lastCompletedDay"
    private static let firstSeenKey = "doseday.review.firstSeen"
    private static let lastVersionKey = "doseday.review.lastPromptVersion"
    private static let lastDateKey = "doseday.review.lastPromptDate"

    private static let minimumCompletedDays = 3
    private static let minimumDaysSinceFirstSeen = 7
    private static let minimumDaysBetween = 60.0

    /// Call once at launch: remembers when the app was first opened.
    static func noteLaunch() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: firstSeenKey) == nil {
            defaults.set(Date(), forKey: firstSeenKey)
        }
    }

    /// Call when the last of a day's doses is ticked off. Counts each day
    /// once, however often its doses are unticked and ticked again.
    static func dayCompleted(_ day: Date) {
        guard !isDemo else { return }
        let defaults = UserDefaults.standard
        let key = day.startOfDay.timeIntervalSince1970
        guard defaults.double(forKey: lastCompletedDayKey) != key else { return }
        defaults.set(key, forKey: lastCompletedDayKey)
        defaults.set(defaults.integer(forKey: completedDaysKey) + 1, forKey: completedDaysKey)
        happyMoment(.dayCompleted)
    }

    /// Asks for a rating after a short pause, if the person is engaged
    /// enough and wasn't asked recently.
    static func happyMoment(_ moment: Moment, hasMedicines: Bool = true) {
        guard !isDemo, isEngaged(hasMedicines: hasMedicines), canAsk() else { return }
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
        let defaults = UserDefaults.standard
        defaults.set(currentVersion, forKey: lastVersionKey)
        defaults.set(Date(), forKey: lastDateKey)
    }

    /// A few full days of doses, or (for people who don't tick doses) a
    /// week since they started, with a medicine in the app.
    private static func isEngaged(hasMedicines: Bool) -> Bool {
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: completedDaysKey) >= minimumCompletedDays { return true }
        guard hasMedicines, let firstSeen = defaults.object(forKey: firstSeenKey) as? Date else { return false }
        return Calendar.current.days(from: firstSeen, to: .now) >= minimumDaysSinceFirstSeen
    }

    private static func canAsk() -> Bool {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: lastVersionKey) == currentVersion { return false }
        if let last = defaults.object(forKey: lastDateKey) as? Date,
           Date().timeIntervalSince(last) < minimumDaysBetween * 86_400 { return false }
        return true
    }

    private static var isDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("-sampleData")
    }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}
