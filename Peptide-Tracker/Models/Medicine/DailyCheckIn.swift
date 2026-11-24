import Foundation

/// How the user felt on a day, picked on the daily check-in card.
struct DailyCheckIn: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Start of the day it belongs to.
    var day: Date
    var mood: Mood

    enum Mood: Int, Codable, CaseIterable, Identifiable {
        case great = 5, good = 4, okay = 3, low = 2, bad = 1

        var id: Int { rawValue }

        var emoji: String {
            switch self {
            case .great: "😄"
            case .good: "🙂"
            case .okay: "😐"
            case .low: "😕"
            case .bad: "😣"
            }
        }

        var title: String {
            switch self {
            case .great: String(localized: "Great")
            case .good: String(localized: "Good")
            case .okay: String(localized: "Okay")
            case .low: String(localized: "Low")
            case .bad: String(localized: "Bad")
            }
        }
    }
}
