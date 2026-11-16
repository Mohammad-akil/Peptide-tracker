import Foundation
import SwiftUI
import WidgetKit

/// Reads and writes the app's saved data from the widget extension, through
/// the App Group both targets share. Only the fields the widgets need are
/// decoded; writes edit the JSON in place so every other field the app
/// keeps is left exactly as it was. The app picks up changes the next time
/// it comes to the foreground.
enum SharedData {
    static let appGroup = "group.com.doseday.ios.shared"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "medicines.json")
    }

    // MARK: Reading

    static func load() -> Snapshot {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return Snapshot() }
        return snapshot
    }

    struct Snapshot: Decodable {
        var medicines: [Medicine] = []
        var doseLogs: [DoseLog] = []
        var checkIns: [CheckIn] = []

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            medicines = (try? c.decodeIfPresent([Medicine].self, forKey: .medicines)) ?? []
            doseLogs = (try? c.decodeIfPresent([DoseLog].self, forKey: .doseLogs)) ?? []
            checkIns = (try? c.decodeIfPresent([CheckIn].self, forKey: .checkIns)) ?? []
        }

        private enum Keys: String, CodingKey { case medicines, doseLogs, checkIns }

        /// Today's doses, in time order, the same way the app lists them.
        func doses(on day: Date = .now) -> [Dose] {
            let day = Calendar.current.startOfDay(for: day)
            let taken = Set(doseLogs.filter { $0.day == day && $0.takenAt != nil }.map { "\($0.medicineID)-\($0.time.minutes)" })
            return medicines
                .filter { Calendar.current.startOfDay(for: $0.createdAt ?? .distantPast) <= day && $0.isScheduled(on: day) }
                .flatMap { medicine in
                    medicine.intakeTimes.compactMap { time -> Dose? in
                        let isTaken = taken.contains("\(medicine.id)-\(time.minutes)")
                        let at = time.on(day)
                        if !isTaken, let created = medicine.createdAt, at < created { return nil }
                        return Dose(medicine: medicine, time: time, at: at, isTaken: isTaken)
                    }
                }
                .sorted { ($0.at, $0.medicine.name) < ($1.at, $1.medicine.name) }
        }

        func mood(on day: Date = .now) -> Mood? {
            let day = Calendar.current.startOfDay(for: day)
            return checkIns.last { $0.day == day }.flatMap { Mood(rawValue: $0.mood) }
        }

        /// The medicine that runs out soonest.
        var lowestSupply: Medicine? {
            medicines.filter { $0.perDay > 0 }.min { $0.daysLeft < $1.daysLeft }
        }
    }

    struct Dose: Identifiable, Hashable {
        let medicine: Medicine
        let time: TimeOfDay
        let at: Date
        let isTaken: Bool
        var id: String { "\(medicine.id)-\(time.minutes)" }
    }

    struct TimeOfDay: Codable, Hashable {
        var hour: Int
        var minute: Int
        var minutes: Int { hour * 60 + minute }
        var label: String { "\(hour):" + String(format: "%02d", minute) }
        func on(_ day: Date) -> Date {
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
    }

    struct Medicine: Decodable, Hashable, Identifiable {
        var id: UUID
        var name: String
        var type: String
        var color: String
        var stock: Int
        var perDay: Int
        var intakeTimes: [TimeOfDay]
        var createdAt: Date?
        var frequency: DoseFrequency?
        var scheduleStart: Date?

        var unitsPerIntake: Int { max(1, perDay / max(intakeTimes.count, 1)) }

        var daysLeft: Int {
            guard perDay > 0 else { return 0 }
            return Int(Double(stock) / (Double(perDay) * (frequency ?? .daily).doseDayFraction))
        }

        func isScheduled(on day: Date) -> Bool {
            (frequency ?? .daily).isDoseDay(day, start: scheduleStart ?? createdAt ?? day)
        }

        var tint: Color {
            switch color {
            case "blue": Color(red: 0.04, green: 0.52, blue: 1)
            case "purple": Color(red: 0.75, green: 0.35, blue: 0.95)
            case "pink": Color(red: 1, green: 0.22, blue: 0.37)
            case "teal": Color(red: 0.19, green: 0.69, blue: 0.78)
            case "amber": Color(red: 1, green: 0.62, blue: 0.04)
            default: Color(red: 0.37, green: 0.36, blue: 0.9)
            }
        }

        var symbol: String {
            switch type {
            case "capsule": "pills.fill"
            case "tablet": "pill.fill"
            case "injection": "syringe.fill"
            case "liquid": "waterbottle.fill"
            case "drops": "drop.fill"
            case "inhaler": "lungs.fill"
            case "cream": "hands.and.sparkles.fill"
            default: "cross.case.fill"
            }
        }
    }

    struct DoseLog: Decodable {
        var medicineID: UUID
        var day: Date
        var time: TimeOfDay
        var takenAt: Date?
    }

    struct CheckIn: Decodable {
        var day: Date
        var mood: Int
    }

    /// Same cases and numbers as the app's `DailyCheckIn.Mood`.
    enum Mood: Int, CaseIterable, Identifiable {
        case bad = 1, low, okay, good, great
        var id: Int { rawValue }
        var title: String { String(describing: self).capitalized }
        var image: Image { Image("mood-\(String(describing: self))") }
        var tint: Color {
            switch self {
            case .great: Color(red: 0.42, green: 0.27, blue: 0.85)
            case .good: Color(red: 0.12, green: 0.62, blue: 0.42)
            case .okay: Color(red: 0.77, green: 0.54, blue: 0.07)
            case .low: Color(red: 0.36, green: 0.42, blue: 0.64)
            case .bad: Color(red: 0.82, green: 0.33, blue: 0.29)
            }
        }
    }

    // MARK: Writing

    /// Ticks today's dose (or un-ticks it), taking its units from stock (or
    /// putting them back), exactly as ticking it in the app does.
    static func toggleDose(medicineID: String, minutes: Int, now: Date = .now) throws {
        try edit { json in
            let day = Calendar.current.startOfDay(for: now)
            let dayValue = day.timeIntervalSinceReferenceDate
            var logs = json["doseLogs"] as? [[String: Any]] ?? []
            var medicines = json["medicines"] as? [[String: Any]] ?? []
            guard let m = medicines.firstIndex(where: { ($0["id"] as? String)?.lowercased() == medicineID.lowercased() }) else { return }
            let perDay = medicines[m]["perDay"] as? Int ?? 1
            let times = (medicines[m]["intakeTimes"] as? [[String: Any]])?.count ?? 1
            let units = max(1, perDay / max(times, 1))
            let stock = medicines[m]["stock"] as? Int ?? 0

            let matches: ([String: Any]) -> Bool = { log in
                guard (log["medicineID"] as? String)?.lowercased() == medicineID.lowercased(),
                      let logDay = log["day"] as? Double, abs(logDay - dayValue) < 1,
                      let time = log["time"] as? [String: Any],
                      let hour = time["hour"] as? Int, let minute = time["minute"] as? Int else { return false }
                return hour * 60 + minute == minutes
            }
            if let index = logs.firstIndex(where: matches), logs[index]["takenAt"] != nil {
                // Un-tick today's dose: back into stock.
                logs.remove(at: index)
                medicines[m]["stock"] = stock + units
            } else {
                logs.removeAll(where: matches)
                logs.append([
                    "id": UUID().uuidString,
                    "medicineID": medicineID.uppercased(),
                    "day": dayValue,
                    "time": ["hour": minutes / 60, "minute": minutes % 60],
                    "units": units,
                    "takenAt": now.timeIntervalSinceReferenceDate,
                ])
                medicines[m]["stock"] = max(0, stock - units)
            }
            json["doseLogs"] = logs
            json["medicines"] = medicines
        }
    }

    /// Saves today's mood, replacing an earlier pick.
    static func logMood(_ mood: Int, now: Date = .now) throws {
        try edit { json in
            let dayValue = Calendar.current.startOfDay(for: now).timeIntervalSinceReferenceDate
            var checkIns = json["checkIns"] as? [[String: Any]] ?? []
            if let index = checkIns.firstIndex(where: { abs(($0["day"] as? Double ?? 0) - dayValue) < 1 }) {
                checkIns[index]["mood"] = mood
            } else {
                checkIns.append(["id": UUID().uuidString, "day": dayValue, "mood": mood])
            }
            json["checkIns"] = checkIns
        }
    }

    private static func edit(_ change: (inout [String: Any]) -> Void) throws {
        guard let url = fileURL else { return }
        let data = (try? Data(contentsOf: url)) ?? Data("{}".utf8)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        change(&json)
        let out = try JSONSerialization.data(withJSONObject: json)
        try out.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        WidgetCenter.shared.reloadAllTimelines()
    }
}
