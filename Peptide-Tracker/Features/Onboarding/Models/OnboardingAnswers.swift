import Foundation

/// What the user picked, applied to settings only when setup finishes.
struct OnboardingAnswers {
    var trackingFor = TrackingFor.me
    var personName = ""
    var leadTime = RefillLeadTime.oneToTwoDays
    var tracksDoses = true
    var reminderTime = TimeOfDay.defaultReminder
    var pharmacyKind = PharmacyKind.one
    var pharmacyName = ""
    var pharmacyPhone = ""

    /// Puts a question back to its default — what Skip does.
    mutating func reset(_ step: OnboardingStep) {
        let defaults = OnboardingAnswers()
        switch step {
        case .who: trackingFor = defaults.trackingFor; personName = ""
        case .refill: leadTime = defaults.leadTime
        case .doses: tracksDoses = defaults.tracksDoses
        case .time: reminderTime = defaults.reminderTime
        case .pharmacy: pharmacyKind = defaults.pharmacyKind; pharmacyName = ""; pharmacyPhone = ""
        default: break
        }
    }

    func apply(to settings: inout AppSettings) {
        settings.trackingFor = trackingFor
        settings.personName = trackingFor == .me ? "" : personName.trimmingCharacters(in: .whitespaces)
        settings.defaultDaysBefore = leadTime.daysBefore
        settings.tracksDoses = tracksDoses
        settings.defaultReminderTime = reminderTime
        settings.pharmacyKind = pharmacyKind
        if pharmacyKind == .one {
            settings.pharmacyName = pharmacyName.trimmingCharacters(in: .whitespaces)
            settings.pharmacyPhone = pharmacyPhone.trimmingCharacters(in: .whitespaces)
        }
    }
}
