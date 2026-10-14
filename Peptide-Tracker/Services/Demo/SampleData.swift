import Foundation

/// The cabinet from the design canvas — six medicines in every urgency
/// state, a month of dose history and six months of refills. Loaded from
/// Settings in debug builds and used by previews.
enum SampleData {
    static func snapshot(now: Date, settings: AppSettings) -> MedicineSnapshot {
        let created = now.startOfDay.adding(days: -180)
        let medicines = [
            Medicine(name: "Amlodipine", strength: "5 mg", type: .tablet, color: .purple,
                     stock: 3, capacity: 30, perDay: 1, intakeTimes: [.init(hour: 8, minute: 0)],
                     reminderDaysBefore: 5, reminderTime: .defaultReminder, createdAt: created),
            Medicine(name: "Vitamin D3", strength: "1000 IU", type: .capsule, color: .pink,
                     stock: 14, capacity: 60, perDay: 2, intakeTimes: [.init(hour: 8, minute: 0), .init(hour: 20, minute: 0)],
                     reminderDaysBefore: 5, reminderTime: .defaultReminder, createdAt: created),
            Medicine(name: "Metformin", strength: "500 mg", type: .capsule, color: .blue,
                     stock: 26, capacity: 60, perDay: 2, intakeTimes: [.init(hour: 8, minute: 0), .init(hour: 20, minute: 0)],
                     reminderDaysBefore: 5, reminderTime: .defaultReminder, createdAt: created),
            Medicine(name: "Insulin glargine", strength: "100 u/ml", type: .injection, color: .amber,
                     stock: 18, capacity: 30, perDay: 1, intakeTimes: [.init(hour: 22, minute: 0)],
                     reminderDaysBefore: 5, reminderTime: .init(hour: 21, minute: 0), createdAt: created),
            Medicine(name: "Hydrocortisone", strength: "1% cream", type: .cream, color: .slate,
                     stock: 40, capacity: 60, perDay: 2, intakeTimes: [.init(hour: 8, minute: 0), .init(hour: 20, minute: 0)],
                     reminderDaysBefore: 5, reminderTime: .defaultReminder, createdAt: created),
            Medicine(name: "Atorvastatin", strength: "20 mg", type: .tablet, color: .teal,
                     stock: 28, capacity: 30, perDay: 1, intakeTimes: [.init(hour: 21, minute: 0)],
                     reminderDaysBefore: 5, reminderTime: .defaultReminder, createdAt: created),
        ]

        var logs: [DoseLog] = []
        // A month of history: nearly everything taken, a few misses so the
        // adherence numbers and week dots have something to show.
        for offset in 1...30 {
            let day = now.startOfDay.adding(days: -offset)
            for (index, medicine) in medicines.enumerated() {
                for time in medicine.intakeTimes {
                    let missed = (offset * 7 + index * 3 + time.hour) % 23 == 0
                    let jitter = TimeInterval(((offset + index) % 9) * 60)
                    logs.append(DoseLog(
                        medicineID: medicine.id, day: day, time: time, units: medicine.unitsPerIntake,
                        takenAt: missed ? nil : time.on(day).addingTimeInterval(jitter)
                    ))
                }
            }
        }
        // Today: the morning round is done except Vitamin D3.
        for medicine in medicines where medicine.name != "Vitamin D3" {
            for time in medicine.intakeTimes where time.on(now) <= now && time.hour < 12 {
                logs.append(DoseLog(
                    medicineID: medicine.id, day: now.startOfDay, time: time, units: medicine.unitsPerIntake,
                    takenAt: time.on(now).addingTimeInterval(120)
                ))
            }
        }

        var refills: [RefillEvent] = []
        for (index, medicine) in medicines.enumerated() {
            let pack = medicine.perDay * 30
            var date = now.startOfDay.adding(days: -(medicine.capacity - medicine.stock) / max(medicine.perDay, 1) - 1)
            while date > now.adding(days: -175) {
                refills.append(RefillEvent(
                    medicineID: medicine.id, medicineName: medicine.name,
                    date: date.addingTimeInterval(TimeInterval(10 + index) * 3600),
                    amount: pack, lastsDays: 30
                ))
                date = date.adding(days: -30)
            }
        }

        return MedicineSnapshot(
            medicines: medicines,
            doseLogs: logs,
            refills: refills,
            settings: settings,
            lastCountdownDay: now.startOfDay.adding(days: -1)
        )
    }
}
