import Foundation

/// How doses went over the last 7, 30 or 90 days: the share taken, what was
/// missed, the run of complete days, each medicine's rate, and the rate over
/// time for the chart. Counts every dose that was due — today only up to now.
struct AdherenceReport {
    enum Period: String, CaseIterable {
        case week = "7", month = "30", quarter = "90"

        var days: Int { Int(rawValue) ?? 7 }
        var title: String { "\(rawValue) days" }
        /// "last 30 days"
        var phrase: String { "last \(rawValue) days" }
    }

    struct Bucket: Identifiable {
        /// The day, or the first day of the week.
        let start: Date
        let due: Int
        let taken: Int

        var id: Date { start }
        var rate: Double? { due > 0 ? Double(taken) / Double(due) : nil }
    }

    struct MedicineRate: Identifiable {
        let medicine: Medicine
        let due: Int
        let taken: Int

        var id: UUID { medicine.id }
        var rate: Double { due > 0 ? Double(taken) / Double(due) : 0 }
    }

    let period: Period
    let now: Date
    let due: Int
    let taken: Int
    /// Days in a row, back from today, with every due dose taken.
    let streak: Int
    let medicines: [MedicineRate]
    /// One per day for 7 and 30 days, one per week for 90.
    let buckets: [Bucket]
    /// Whether the chart's bars are weeks rather than days.
    let isWeekly: Bool

    var missed: Int { due - taken }
    var rate: Double? { due > 0 ? Double(taken) / Double(due) : nil }

    @MainActor
    init(store: MedicineStore, period: Period, now: Date = .now) {
        self.period = period
        self.now = now
        let today = now.startOfDay
        let days = (0..<period.days).map { today.adding(days: $0 - period.days + 1) }

        var daily: [(day: Date, due: Int, taken: Int)] = []
        var perMedicine: [UUID: (medicine: Medicine, due: Int, taken: Int)] = [:]
        for day in days {
            // Today counts only what was due by now (or already taken).
            let doses = store.doses(on: day).filter { $0.isTaken || $0.scheduledAt <= now }
            daily.append((day, doses.count, doses.filter(\.isTaken).count))
            for dose in doses {
                var entry = perMedicine[dose.medicine.id] ?? (dose.medicine, 0, 0)
                entry.due += 1
                if dose.isTaken { entry.taken += 1 }
                perMedicine[dose.medicine.id] = entry
            }
        }

        due = daily.reduce(0) { $0 + $1.due }
        taken = daily.reduce(0) { $0 + $1.taken }
        medicines = perMedicine.values
            .map { MedicineRate(medicine: $0.medicine, due: $0.due, taken: $0.taken) }
            .sorted { ($0.rate, $0.medicine.name) < ($1.rate, $1.medicine.name) }

        // The streak skips days with nothing due, and today while its doses
        // are still to come.
        var streak = 0
        for entry in daily.reversed() where entry.due > 0 {
            if entry.taken < entry.due {
                if entry.day == today { continue }
                break
            }
            streak += 1
        }
        self.streak = streak

        isWeekly = period == .quarter
        if isWeekly {
            buckets = stride(from: 0, to: daily.count, by: 7).map { start in
                let week = daily[start..<min(start + 7, daily.count)]
                return Bucket(start: week.first!.day, due: week.reduce(0) { $0 + $1.due }, taken: week.reduce(0) { $0 + $1.taken })
            }
        } else {
            buckets = daily.map { Bucket(start: $0.day, due: $0.due, taken: $0.taken) }
        }
    }
}

extension Double {
    /// "92%"
    var percentLabel: String { "\(Int((self * 100).rounded()))%" }
}
