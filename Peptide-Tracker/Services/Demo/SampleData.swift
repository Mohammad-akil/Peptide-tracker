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
                     reminderDaysBefore: 5, reminderTime: .init(hour: 21, minute: 0), createdAt: created,
                     openedAt: now.startOfDay.adding(days: -9), usableDaysAfterOpening: 28, prepMinutes: 30),
            Medicine(name: "Hydrocortisone", strength: "1% cream", type: .cream, color: .slate,
                     stock: 40, capacity: 60, perDay: 2, intakeTimes: [.init(hour: 8, minute: 0), .init(hour: 20, minute: 0)],
                     reminderDaysBefore: 5, reminderTime: .defaultReminder, createdAt: created),
            Medicine(name: "Atorvastatin", strength: "20 mg", type: .tablet, color: .teal,
                     stock: 28, capacity: 30, perDay: 1, intakeTimes: [.init(hour: 21, minute: 0)],
                     reminderDaysBefore: 5, reminderTime: .defaultReminder, createdAt: created),
        ]

        let injection = medicines[3]
        var siteClock: [InjectionSite: Date] = [:]
        var logs: [DoseLog] = []
        // A month of history: nearly everything taken, a few misses so the
        // adherence numbers and week dots have something to show.
        for offset in 1...30 {
            let day = now.startOfDay.adding(days: -offset)
            for (index, medicine) in medicines.enumerated() {
                for time in medicine.intakeTimes {
                    let missed = (offset * 7 + index * 3 + time.hour) % 23 == 0
                    let jitter = TimeInterval(((offset + index) % 9) * 60)
                    let takenAt = missed ? nil : time.on(day).addingTimeInterval(jitter)
                    // Injections rotate round the body, for the site map.
                    var site: InjectionSite?
                    if medicine.id == injection.id, let takenAt {
                        site = InjectionSite.next(lastUsed: siteClock)
                        siteClock[site!] = takenAt
                    }
                    logs.append(DoseLog(
                        medicineID: medicine.id, day: day, time: time, units: medicine.unitsPerIntake,
                        takenAt: takenAt, site: site
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

        // Mood most days, gently up.
        let moods: [DailyCheckIn.Mood] = [.okay, .good, .good, .great, .low, .good, .great]
        let checkIns = (0..<28).compactMap { offset -> DailyCheckIn? in
            guard offset % 5 != 3 else { return nil }
            return DailyCheckIn(day: now.startOfDay.adding(days: -offset), mood: moods[offset % moods.count])
        }.reversed()

        // A weigh-in every few days, trending down.
        let weights = stride(from: 56, through: 0, by: -4).map { offset in
            WeightEntry(day: now.startOfDay.adding(days: -offset), kilograms: 84.0 - Double(56 - offset) * 0.09 + Double(offset % 3) * 0.2)
        }

        // A handful of side effects, mostly the day after an injection.
        let effects: [(days: Int, kind: SideEffectEntry.Kind, severity: SideEffectEntry.Severity)] = [
            (2, .nausea, .mild), (6, .nausea, .moderate), (9, .fatigue, .mild),
            (13, .nausea, .mild), (16, .headache, .mild), (20, .siteReaction, .mild), (23, .nausea, .mild),
        ]
        let sideEffects = effects.map { effect in
            SideEffectEntry(
                date: now.startOfDay.adding(days: -effect.days).addingTimeInterval(10 * 3600),
                kind: effect.kind,
                severity: effect.severity,
                medicineID: injection.id,
                site: effect.kind == .siteReaction ? .thighLeft : nil
            )
        }

        let contacts = [
            HealthContact(name: "Dr. Sarah Patel", role: .doctor, phone: "+44 20 7946 0018", email: "reception@example.com"),
            HealthContact(name: "City Pharmacy", role: .pharmacist, phone: "+44 20 7946 0412"),
            HealthContact(name: "Diabetes nurse", role: .nurse, phone: "+44 20 7946 0733", email: "nurse@example.com"),
        ]

        return MedicineSnapshot(
            medicines: medicines,
            doseLogs: logs,
            refills: refills,
            settings: settings,
            lastCountdownDay: now.startOfDay.adding(days: -1),
            contacts: contacts,
            checkIns: Array(checkIns),
            weights: weights,
            sideEffects: sideEffects
        )
    }
}
