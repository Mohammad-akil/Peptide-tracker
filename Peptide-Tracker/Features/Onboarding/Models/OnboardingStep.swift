import Foundation

/// The screens of first-run setup, in order. Every question changes how the
/// app behaves; skipping one keeps its default.
enum OnboardingStep: Int, CaseIterable, Comparable {
    // Raw names double as `-onboarding <step>` debug launch arguments.
    case getStarted, tour, welcome
    case journey, route, medication, dose, device, frequency, education
    case height, weight, start, goal, momentum, pace, comparison
    case sideEffects, reason, settingUp

    static let questionCount = 13

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Filled segments of the progress bar. Info screens share the
    /// question before them.
    var progress: Int {
        switch self {
        case .getStarted, .tour, .welcome: 0
        case .journey: 1
        case .route: 2
        case .medication: 3
        case .dose: 4
        case .device: 5
        case .frequency, .education: 6
        case .height: 7
        case .weight: 8
        case .start: 9
        case .goal, .momentum: 10
        case .pace, .comparison: 11
        case .sideEffects: 12
        case .reason, .settingUp: 13
        }
    }

    var isQuestion: Bool {
        [.journey, .route, .medication, .dose, .device, .frequency, .height, .weight, .start, .goal, .pace, .sideEffects, .reason].contains(self)
    }

    var next: Self? { Self(rawValue: rawValue + 1) }
    var previous: Self? { Self(rawValue: rawValue - 1) }
}
