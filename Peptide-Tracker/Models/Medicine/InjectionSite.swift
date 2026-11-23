import Foundation

/// Where an injection went, so the next one can go somewhere else. The
/// four areas used for injections under the skin, each side.
enum InjectionSite: String, Codable, CaseIterable, Identifiable {
    // The usual subcutaneous sites, which rotation walks through.
    case abdomenLeft, abdomenRight, thighLeft, thighRight
    case armLeft, armRight, gluteLeft, gluteRight
    // Every other major part of the body map, so any spot can be logged.
    case shoulderLeft, shoulderRight, chestLeft, chestRight
    case frontArmLeft, frontArmRight, forearmLeft, forearmRight
    case flankLeft, flankRight, backLeft, backRight
    case hamstringLeft, hamstringRight, calfLeft, calfRight

    var id: String { rawValue }

    enum Area: String, Codable, CaseIterable, Identifiable {
        var id: String { rawValue }

        case abdomen, thigh, arm, glute
        case shoulder, chest, frontArm, forearm, flank, back, hamstring, calf

        var title: String {
            switch self {
            case .abdomen: "Abdomen"
            case .thigh: "Thigh"
            case .arm: "Back of arm"
            case .glute: "Glute"
            case .shoulder: "Shoulder"
            case .chest: "Chest"
            case .frontArm: "Front of arm"
            case .forearm: "Forearm"
            case .flank: "Side"
            case .back: "Back"
            case .hamstring: "Back of thigh"
            case .calf: "Calf"
            }
        }

        /// The areas rotation suggests from, and that Settings can switch
        /// off. The rest can always be picked but are never suggested.
        static let rotationAreas: [Area] = [.abdomen, .thigh, .arm, .glute]
    }

    enum Side { case left, right }

    var area: Area {
        switch self {
        case .abdomenLeft, .abdomenRight: .abdomen
        case .thighLeft, .thighRight: .thigh
        case .armLeft, .armRight: .arm
        case .gluteLeft, .gluteRight: .glute
        case .shoulderLeft, .shoulderRight: .shoulder
        case .chestLeft, .chestRight: .chest
        case .frontArmLeft, .frontArmRight: .frontArm
        case .forearmLeft, .forearmRight: .forearm
        case .flankLeft, .flankRight: .flank
        case .backLeft, .backRight: .back
        case .hamstringLeft, .hamstringRight: .hamstring
        case .calfLeft, .calfRight: .calf
        }
    }

    var side: Side {
        switch self {
        case .abdomenLeft, .thighLeft, .armLeft, .gluteLeft,
             .shoulderLeft, .chestLeft, .frontArmLeft, .forearmLeft,
             .flankLeft, .backLeft, .hamstringLeft, .calfLeft: .left
        default: .right
        }
    }

    /// Back of the arm, glutes, back and back of the thigh are drawn on the
    /// back of the body; the rest on the front (shoulders and calves show
    /// on both).
    var isOnBack: Bool { [.arm, .glute, .back, .hamstring].contains(area) }

    /// "Left abdomen", "Right back of arm"
    var title: String {
        let side = side == .left ? "Left" : "Right"
        return "\(side) \(area.title.lowercased())"
    }

    /// The order rotation walks through: round the body, alternating sides,
    /// so consecutive injections land far apart. Only the usual
    /// subcutaneous sites; the others are picked by hand.
    static let rotation: [InjectionSite] = [
        .abdomenLeft, .abdomenRight, .thighLeft, .thighRight,
        .armLeft, .armRight, .gluteLeft, .gluteRight,
    ]

    /// Every site, rotation's first, for pickers and reports.
    static let all: [InjectionSite] = rotation + allCases.filter { !rotation.contains($0) }
}

// MARK: - Rotation

extension InjectionSite {
    /// Where the next injection should go. Of the sites in areas the user
    /// injects (`skipping` holds the ones they don't), a site never used
    /// yet comes first, else the one that has rested longest. Ties go in
    /// `rotation` order, starting after the most recent site, so a fresh
    /// start still walks round the body and alternates sides. Following the
    /// suggestion every time is the plain rotation; picking another site
    /// once doesn't throw it off, because rest time decides.
    static func next(lastUsed: [InjectionSite: Date], skipping skipped: Set<Area> = []) -> InjectionSite {
        let inUse = rotation.filter { !skipped.contains($0.area) }
        let candidates = inUse.isEmpty ? rotation : inUse

        let mostRecent = lastUsed.max { $0.value < $1.value }?.key
        let start = mostRecent.flatMap { rotation.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        let ordered = candidates.sorted {
            cyclicDistance(from: start, to: $0) < cyclicDistance(from: start, to: $1)
        }

        if let fresh = ordered.first(where: { lastUsed[$0] == nil }) { return fresh }
        // `min(by:)` keeps the first of equal elements, so ties stay in order.
        return ordered.min { lastUsed[$0]! < lastUsed[$1]! } ?? candidates[0]
    }

    /// The next `count` sites, as if each suggestion were used in turn —
    /// for the reminders of injections still to come.
    static func upcoming(_ count: Int, lastUsed: [InjectionSite: Date], skipping skipped: Set<Area> = []) -> [InjectionSite] {
        var used = lastUsed
        var clock = used.values.max() ?? .distantPast
        return (0..<max(count, 0)).map { _ in
            let site = next(lastUsed: used, skipping: skipped)
            clock = clock.addingTimeInterval(1)
            used[site] = clock
            return site
        }
    }

    private static func cyclicDistance(from start: Int, to site: InjectionSite) -> Int {
        let index = rotation.firstIndex(of: site) ?? 0
        return (index - start + rotation.count) % rotation.count
    }
}
