import Foundation

/// The screens of first-run setup, in order. Every question changes how the
/// app behaves; skipping one keeps its default.
enum OnboardingStep: Int, CaseIterable, Comparable {
    // Raw names double as `-onboarding <step>` debug launch arguments.
    case getStarted, tour, welcome, who, refill, benefit, doses, time, pharmacy, plan

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
        case .pharmacy, .plan: 5
        }
    }

    var isQuestion: Bool { [.who, .refill, .doses, .time, .pharmacy].contains(self) }

    var next: Self? { Self(rawValue: rawValue + 1) }
    var previous: Self? { Self(rawValue: rawValue - 1) }
}
