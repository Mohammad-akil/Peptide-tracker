import SwiftUI

/// Someone involved in the user's care — a GP, a specialist, a carer —
/// with the ways to reach them.
struct HealthContact: Identifiable, Codable, Hashable {
    var id = UUID()
    var name = ""
    var role = Role.doctor
    var phone = ""
    var email = ""
    /// "Sees me every 3 months", "Practice: Elm Road". Optional.
    var notes = ""

    enum Role: String, Codable, CaseIterable, Identifiable {
        case doctor, specialist, nurse, pharmacist, caregiver, clinic, other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .doctor: "Doctor"
            case .specialist: "Specialist"
            case .nurse: "Nurse"
            case .pharmacist: "Pharmacist"
            case .caregiver: "Carer"
            case .clinic: "Clinic"
            case .other: "Other"
            }
        }

        var symbol: String {
            switch self {
            case .doctor: "stethoscope"
            case .specialist: "heart.text.square.fill"
            case .nurse: "cross.fill"
            case .pharmacist: "cross.case.fill"
            case .caregiver: "figure.2.arms.open"
            case .clinic: "building.2.fill"
            case .other: "person.fill"
            }
        }

        var tint: Color {
            switch self {
            case .doctor: Color(hex: 0x0A84FF)
            case .specialist: Color(hex: 0xFF375F)
            case .nurse: Color(hex: 0x30B0C7)
            case .pharmacist: Color(hex: 0x30D158)
            case .caregiver: Color(hex: 0xFF9F0A)
            case .clinic: Color(hex: 0x5E5CE6)
            case .other: Color(hex: 0x8E8E93)
            }
        }
    }

    /// Digits and "+" only, for tel: and sms: links.
    var dialablePhone: String { phone.filter { $0.isNumber || $0 == "+" } }

    var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }
}
