import Foundation

/// Where an injection went, so the next one can go somewhere else. The
/// four areas used for injections under the skin, each side.
enum InjectionSite: String, Codable, CaseIterable, Identifiable {
    case abdomenLeft, abdomenRight, thighLeft, thighRight
    case armLeft, armRight, gluteLeft, gluteRight

    var id: String { rawValue }

    enum Area: String, CaseIterable {
        case abdomen, thigh, arm, glute

        var title: String {
            switch self {
            case .abdomen: "Abdomen"
            case .thigh: "Thigh"
            case .arm: "Back of arm"
            case .glute: "Glute"
            }
        }
    }

    enum Side { case left, right }

    var area: Area {
        switch self {
        case .abdomenLeft, .abdomenRight: .abdomen
        case .thighLeft, .thighRight: .thigh
        case .armLeft, .armRight: .arm
        case .gluteLeft, .gluteRight: .glute
        }
    }

    var side: Side {
        switch self {
        case .abdomenLeft, .thighLeft, .armLeft, .gluteLeft: .left
        case .abdomenRight, .thighRight, .armRight, .gluteRight: .right
        }
    }

    /// Arms and glutes are drawn on the back of the body, the rest on the front.
    var isOnBack: Bool { area == .arm || area == .glute }

    /// "Left abdomen", "Right back of arm"
    var title: String {
        let side = side == .left ? "Left" : "Right"
        return "\(side) \(area.title.lowercased())"
    }

    /// The order rotation walks through: round the body, alternating sides,
    /// so consecutive injections land far apart.
    static let rotation: [InjectionSite] = [
        .abdomenLeft, .abdomenRight, .thighLeft, .thighRight,
        .armLeft, .armRight, .gluteLeft, .gluteRight,
    ]
}
