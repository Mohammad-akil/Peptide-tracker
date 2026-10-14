import Foundation

/// The editable state behind the Add / Edit form, with validation and the
/// live run-out preview. Kept apart from the view so the rules are easy to
/// read in one place.
struct MedicineDraft {
    var name = ""
    var strength = ""
    var type: MedicineType = .capsule
    var color: MedicineColor = .blue
    var stock = 0
    var perDay = 0
    var reminderDaysBefore = 5
    var reminderTime = TimeOfDay.defaultReminder

    /// The medicine being edited, if any — keeps its id, capacity and
    /// schedule.
    private(set) var original: Medicine?

    init(settings: AppSettings) {
        reminderDaysBefore = settings.defaultDaysBefore
        reminderTime = settings.defaultReminderTime
    }

    init(editing medicine: Medicine) {
        original = medicine
        name = medicine.name
        strength = medicine.strength
        type = medicine.type
        color = medicine.color
        stock = medicine.stock
        perDay = medicine.perDay
        reminderDaysBefore = medicine.reminderDaysBefore
        reminderTime = medicine.reminderTime
    }

    var isEditing: Bool { original != nil }

    // MARK: Validation

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var nameError: String? { trimmedName.isEmpty ? "Add a name" : nil }

    var perDayError: String? {
        perDay < 1 ? "\(type.perDayLabel) must be at least 1" : nil
    }

    var isValid: Bool { nameError == nil && perDayError == nil }

    // MARK: Preview

    /// What the form would save, or nil while the daily amount is missing.
    func previewMedicine() -> Medicine? {
        guard perDay > 0 else { return nil }
        return build()
    }

    func build() -> Medicine {
        let intakeTimes: [TimeOfDay] = if let original, original.perDay == perDay {
            original.intakeTimes
        } else {
            TimeOfDay.defaultSchedule(perDay: perDay)
        }
        return Medicine(
            id: original?.id ?? UUID(),
            name: trimmedName,
            strength: strength.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            color: color,
            stock: stock,
            capacity: max(original?.capacity ?? 0, stock),
            perDay: max(perDay, 1),
            intakeTimes: intakeTimes,
            reminderDaysBefore: reminderDaysBefore,
            reminderTime: reminderTime,
            remindersPaused: original?.remindersPaused ?? false,
            orderedAt: original?.orderedAt,
            createdAt: original?.createdAt ?? .now
        )
    }
}
