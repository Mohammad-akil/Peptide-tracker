import Foundation

/// The screens of first-run setup, in order. Every question changes how the
/// app behaves; skipping one keeps its default.
enum OnboardingStep: Int, CaseIterable, Comparable {
    // Raw names double as `-onboarding <step>` debug launch arguments.
    case getStarted, tour, welcome, who, refill, benefit, doses, time, pharmacy, notifications, settingUp, plan

    static let questionCount = 5

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Filled segments of the progress bar.
    var progress: Int {
        switch self {
        case .getStarted, .tour, .welcome: 0
        case .who: 1
        case .refill, .benefit: 2
        case .doses: 3
        case .time: 4
        case .pharmacy, .notifications, .settingUp, .plan: 5
        }
    }

    var isQuestion: Bool { [.who, .refill, .doses, .time, .pharmacy].contains(self) }

    var next: Self? { Self(rawValue: rawValue + 1) }
    /// Back skips the "setting up" beat; it only plays going forward.
    var previous: Self? {
        let previous = Self(rawValue: rawValue - 1)
        return previous == .settingUp ? previous?.previous : previous
    }
}
