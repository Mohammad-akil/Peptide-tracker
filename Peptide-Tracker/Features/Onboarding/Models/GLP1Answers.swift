import Foundation

/// Onboarding GLP-1 Q1: where the user is in their GLP-1 journey.
enum GLP1Journey: String, Codable, CaseIterable {
    case taking, notStarted

    var title: String {
        switch self {
        case .taking: String(localized: "I’m already taking a GLP-1")
        case .notStarted: String(localized: "I haven’t started a GLP-1 yet")
        }
    }
}

/// Onboarding GLP-1 Q2: how the medication is taken.
enum GLP1Route: String, Codable, CaseIterable {
    case injection, pill, notSure

    var title: String {
        switch self {
        case .injection: String(localized: "Injection")
        case .pill: String(localized: "Pill")
        case .notSure: String(localized: "Not sure yet")
        }
    }
}

/// Onboarding GLP-1 Q3: which GLP-1 medication.
enum GLP1Medication: String, Codable, CaseIterable {
    case zepbound, mounjaro, ozempic, wegovy, wegovyPill, rybelsus
    case saxenda, trulicity, victoza, liraglutide, xultophy, soliqua
    case compoundedTirzepatide, compoundedSemaglutide
    case other, dontKnow

    var title: String {
        switch self {
        case .zepbound: String(localized: "Zepbound")
        case .mounjaro: String(localized: "Mounjaro")
        case .ozempic: String(localized: "Ozempic")
        case .wegovy: String(localized: "Wegovy")
        case .wegovyPill: String(localized: "Wegovy pill")
        case .rybelsus: String(localized: "Rybelsus")
        case .saxenda: String(localized: "Saxenda")
        case .trulicity: String(localized: "Trulicity")
        case .victoza: String(localized: "Victoza")
        case .liraglutide: String(localized: "Liraglutide (generic)")
        case .xultophy: String(localized: "Xultophy")
        case .soliqua: String(localized: "Soliqua")
        case .compoundedTirzepatide: String(localized: "Tirzepatide")
        case .compoundedSemaglutide: String(localized: "Semaglutide")
        case .other: String(localized: "Other")
        case .dontKnow: String(localized: "I don’t know")
        }
    }

    var subtitle: String {
        switch self {
        case .zepbound, .mounjaro: String(localized: "Tirzepatide · weekly injection")
        case .ozempic: String(localized: "Semaglutide · weekly injection")
        case .wegovy: String(localized: "Semaglutide · weekly injection")
        case .wegovyPill: String(localized: "Semaglutide · daily pill")
        case .rybelsus: String(localized: "Semaglutide · daily pill")
        case .saxenda, .victoza: String(localized: "Liraglutide · daily injection")
        case .trulicity: String(localized: "Dulaglutide · weekly injection")
        case .liraglutide: String(localized: "Liraglutide · daily injection")
        case .xultophy: String(localized: "Insulin degludec + liraglutide · daily")
        case .soliqua: String(localized: "Insulin glargine + lixisenatide · daily")
        case .compoundedTirzepatide: String(localized: "Compounded · weekly injection")
        case .compoundedSemaglutide: String(localized: "Compounded · weekly injection")
        case .other: String(localized: "Type the name of your medication")
        case .dontKnow: String(localized: "That’s fine, you can add it later")
        }
    }

    var isPill: Bool { [.rybelsus, .wegovyPill].contains(self) }
    var isInjectable: Bool { !isPill }

    /// Insulin combinations are dosed in units; everything else in mg.
    var doseUnit: String { [.xultophy, .soliqua].contains(self) ? "units" : "mg" }

    /// "0.25 mg", "16 units".
    func doseLabel(_ dose: Double) -> String {
        String(localized: "\(dose.formatted(.number.precision(.fractionLength(0...2)))) \(doseUnit)")
    }

    /// The choices worth showing for how the user takes it. Other and
    /// I don't know are always there.
    static func options(for route: GLP1Route?) -> [Self] {
        let named = allCases.filter { $0 != .other && $0 != .dontKnow }
        let shown: [Self] = switch route {
        case .injection: named.filter(\.isInjectable)
        case .pill: named.filter(\.isPill)
        case .notSure, nil: named
        }
        return shown + [.other, .dontKnow]
    }
}

extension GLP1Medication {
    /// The usual doses, in `doseUnit`, for the dose question. Tirzepatide, liraglutide
    /// and the pills step up differently from injected semaglutide, so each
    /// gets its own ladder; everything else uses the semaglutide one.
    func doses(route: GLP1Route?) -> [Double] {
        switch self {
        case .zepbound, .mounjaro, .compoundedTirzepatide: [2.5, 5, 7.5, 10, 12.5, 15]
        case .rybelsus: [3, 7, 14]
        case .wegovyPill: [1.5, 4, 9, 25]
        case .saxenda, .victoza, .liraglutide: [0.6, 1.2, 1.8, 2.4, 3]
        case .xultophy: [10, 16, 20, 30, 40, 50]
        case .soliqua: [15, 20, 30, 40, 50, 60]
        case .trulicity: [0.75, 1.5, 3, 4.5]
        default: [0.25, 0.5, 1, 1.7, 2, 2.4]
        }
    }
}

/// Onboarding GLP-1 Q5: what the injection is given with. Not asked for pills.
enum GLP1Device: String, Codable, CaseIterable {
    case singleUsePen, autoInjector, syringeAndVial, other

    var title: String {
        switch self {
        case .singleUsePen: String(localized: "Single use pen")
        case .autoInjector: String(localized: "Autoinjector")
        case .syringeAndVial: String(localized: "Syringe and vial")
        case .other: String(localized: "Other")
        }
    }
}

/// Onboarding GLP-1 Q6: how often a dose is due.
enum GLP1Frequency: CaseIterable {
    case daily, weekly, everyTwoWeeks, custom

    var title: String {
        switch self {
        case .daily: String(localized: "Every day")
        case .weekly: String(localized: "Every 7 days")
        case .everyTwoWeeks: String(localized: "Every 14 days")
        case .custom: String(localized: "Custom")
        }
    }

    /// Days between doses; nil for Custom, which uses the picker.
    var fixedDays: Int? {
        switch self {
        case .daily: 1
        case .weekly: 7
        case .everyTwoWeeks: 14
        case .custom: nil
        }
    }
}

/// Onboarding: how fast to aim for the goal, per week.
enum GoalPace: Int, CaseIterable {
    case steady, balanced, fast

    var kilogramsPerWeek: Double {
        switch self {
        case .steady: 0.3
        case .balanced: 0.7
        case .fast: 1.1
        }
    }

    var title: String {
        switch self {
        case .steady: String(localized: "Slow and steady")
        case .balanced: String(localized: "Recommended")
        case .fast: String(localized: "Fast")
        }
    }

    var symbol: String {
        switch self {
        case .steady: "tortoise.fill"
        case .balanced: "figure.walk"
        case .fast: "hare.fill"
        }
    }

    var message: String {
        switch self {
        case .steady: String(localized: "Gentle and sustainable. Perfect for building habits that last.")
        case .balanced: String(localized: "A healthy, realistic pace that fits most lifestyles. Great choice!")
        case .fast: String(localized: "Ambitious! Faster loss can bring more side effects, so check in with your doctor along the way.")
        }
    }
}

/// Onboarding: side effects the user worries about. Several can be picked;
/// "not concerned" stands alone.
enum SideEffectConcern: String, Codable, CaseIterable {
    case nausea, heartburn, muscleLoss, injectionAnxiety, other, notConcerned

    var title: String {
        switch self {
        case .nausea: String(localized: "Nausea")
        case .heartburn: String(localized: "Heartburn")
        case .muscleLoss: String(localized: "Muscle loss")
        case .injectionAnxiety: String(localized: "Injection anxiety")
        case .other: String(localized: "Other")
        case .notConcerned: String(localized: "I’m not concerned")
        }
    }

    var subtitle: String {
        switch self {
        case .nausea: String(localized: "Feeling sick, especially after a dose")
        case .heartburn: String(localized: "Reflux or a burning feeling")
        case .muscleLoss: String(localized: "Keeping strength while losing weight")
        case .injectionAnxiety: String(localized: "Nerves about giving the shot")
        case .other: String(localized: "Type what’s on your mind")
        case .notConcerned: String(localized: "Nothing in particular right now")
        }
    }

    var symbol: String {
        switch self {
        case .nausea: "face.dashed.fill"
        case .heartburn: "flame.fill"
        case .muscleLoss: "dumbbell.fill"
        case .injectionAnxiety: "syringe.fill"
        case .other: "pencil"
        case .notConcerned: "hand.thumbsup.fill"
        }
    }
}

/// Onboarding: why the user wants to reach their goal. Several can be picked.
enum GoalReason: String, Codable, CaseIterable {
    case confidence, freshStart, energy, metabolicHealth, lovedOnes, event, clothes, other

    var title: String {
        switch self {
        case .confidence: String(localized: "I want to feel more confident in my body")
        case .freshStart: String(localized: "I’m ready for a fresh start")
        case .energy: String(localized: "I want to boost my energy")
        case .metabolicHealth: String(localized: "I want to improve my metabolic health")
        case .lovedOnes: String(localized: "I want to show up for the people I love")
        case .event: String(localized: "I have a special event or milestone coming up")
        case .clothes: String(localized: "I want to feel good wearing the clothes I love again")
        case .other: String(localized: "Something else")
        }
    }

    var symbol: String {
        switch self {
        case .confidence: "figure.stand"
        case .freshStart: "sunrise.fill"
        case .energy: "bolt.fill"
        case .metabolicHealth: "heart.text.square.fill"
        case .lovedOnes: "figure.2.and.child.holdinghands"
        case .event: "party.popper.fill"
        case .clothes: "tshirt.fill"
        case .other: "pencil"
        }
    }
}
