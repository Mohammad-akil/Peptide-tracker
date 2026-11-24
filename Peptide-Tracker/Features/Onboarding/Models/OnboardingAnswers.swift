import Foundation

/// What the user picked, applied to settings only when setup finishes.
struct OnboardingAnswers {
    var journey: GLP1Journey?
    var route: GLP1Route?
    var medication: GLP1Medication?
    var otherMedication = ""
    /// In mg; nil when Other is picked or nothing is.
    var dose: Double?
    var isOtherDose = false
    var otherDose = ""
    var device: GLP1Device?
    var otherDevice = ""
    var frequency: GLP1Frequency?
    /// The wheel under Custom, 1 to 21.
    var customIntervalDays = 3
    /// Nil until the wheel is touched, so Skip leaves the profile empty.
    var heightCm: Int?
    var usesImperialHeight = Locale.current.measurementSystem == .us
    static let defaultHeightCm = 170
    var weightUnit: WeightUnit = Locale.current.measurementSystem == .us ? .lb : .kg
    var currentWeightKg: Double?
    var startWeightKg: Double?
    var startDate: Date?
    static let defaultWeightKg = 80.0
    var goalWeightKg: Double?
    var pace = GoalPace.balanced
    var concerns: Set<SideEffectConcern> = []
    var otherConcern = ""
    var reasons: Set<GoalReason> = []
    var otherReason = ""

    /// Where the goal slider starts: the top of the healthy BMI range, or
    /// 10% below now if that's closer, never above the current weight.
    var suggestedGoalKg: Double {
        let current = currentWeightKg ?? Self.defaultWeightKg
        let metres = Double(heightCm ?? Self.defaultHeightCm) / 100
        let healthyTop = 24.9 * metres * metres
        return min(current, max(healthyTop, current * 0.9))
    }

    /// The medication as the setup screen names it: the typed name for Other.
    var medicationLabel: String {
        guard let medication else { return String(localized: "Not set") }
        let typed = otherMedication.trimmingCharacters(in: .whitespaces)
        return medication == .other && !typed.isEmpty ? typed : medication.title
    }

    /// The device question is only for injections.
    var asksDevice: Bool { route != .pill }

    /// Steps that don't apply to these answers: the device for pills, and
    /// where you started for someone who hasn't started.
    func asks(_ step: OnboardingStep) -> Bool {
        switch step {
        case .device: asksDevice
        case .start: journey != .notStarted
        case .momentum: goalWeightKg != nil
        // Pace only matters when there's weight to lose.
        case .pace: (goalWeightKg ?? .infinity) < (currentWeightKg ?? Self.defaultWeightKg) - 0.05
        default: true
        }
    }

    /// Weigh-ins to save: the start weight on its date, then today's.
    var weighIns: [(kilograms: Double, day: Date)] {
        var entries: [(kilograms: Double, day: Date)] = []
        if journey != .notStarted, let startWeightKg {
            entries.append((startWeightKg, startDate ?? .now))
        }
        if let currentWeightKg { entries.append((currentWeightKg, .now)) }
        return entries
    }

    /// Days between doses, once a frequency is picked.
    var intervalDays: Int? {
        guard let frequency else { return nil }
        return frequency.fixedDays ?? customIntervalDays
    }

    /// Puts a question back to its default — what Skip does.
    mutating func reset(_ step: OnboardingStep) {
        switch step {
        case .journey: journey = nil
        case .route: route = nil
        case .medication: medication = nil; otherMedication = ""
        case .dose: dose = nil; isOtherDose = false; otherDose = ""
        case .device: device = nil; otherDevice = ""
        case .frequency: frequency = nil; customIntervalDays = 3
        case .height: heightCm = nil
        case .weight: currentWeightKg = nil
        case .start: startWeightKg = nil; startDate = nil
        case .goal: goalWeightKg = nil
        case .pace: pace = .balanced
        case .sideEffects: concerns = []; otherConcern = ""
        case .reason: reasons = []; otherReason = ""
        default: break
        }
    }

    func apply(to settings: inout AppSettings) {
        settings.glp1Journey = journey
        settings.glp1Route = route
        settings.glp1Medication = medication
        settings.glp1OtherMedication = medication == .other ? otherMedication.trimmingCharacters(in: .whitespaces) : ""
        settings.glp1Dose = isOtherDose ? otherDose.trimmingCharacters(in: .whitespaces) : (dose.map { (medication ?? .dontKnow).doseLabel($0) } ?? "")
        let injects = route != .pill
        settings.glp1Device = injects ? device : nil
        settings.glp1OtherDevice = injects && device == .other ? otherDevice.trimmingCharacters(in: .whitespaces) : ""
        settings.glp1IntervalDays = intervalDays
        if let heightCm { settings.heightCm = Double(heightCm) }
        if heightCm != nil || currentWeightKg != nil || startWeightKg != nil {
            settings.weightUnit = weightUnit
        }
        settings.glp1StartDate = journey == .notStarted ? nil : startDate
        settings.goalWeightKg = goalWeightKg
        settings.weeklyGoalKg = asks(.pace) ? pace.kilogramsPerWeek : nil
        settings.sideEffectConcerns = route == .pill ? concerns.subtracting([.injectionAnxiety]) : concerns
        settings.goalReasons = reasons
        settings.otherGoalReason = reasons.contains(.other) ? otherReason.trimmingCharacters(in: .whitespaces) : ""
        settings.otherSideEffectConcern = concerns.contains(.other) ? otherConcern.trimmingCharacters(in: .whitespaces) : ""
    }
}
