import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// "Download your data": everything the app keeps, as three CSV files that
/// open in Numbers, Excel or Google Sheets — every dose (taken or missed,
/// with when and where), every medicine, and every refill. Free for
/// everyone: it's the user's own data. Built only when the share sheet asks.
struct DataExportFile: Transferable {
    enum Kind: CaseIterable {
        case doses, medicines, refills, health, calculators, sideEffects

        var fileName: String {
            switch self {
            case .doses: "Doseday – dose history.csv"
            case .medicines: "Doseday – medicines.csv"
            case .refills: "Doseday – refills.csv"
            case .health: "Doseday – mood and weight.csv"
            case .calculators: "Doseday – calculator history.csv"
            case .sideEffects: "Doseday – side effects.csv"
            }
        }
    }

    let kind: Kind
    let medicines: [Medicine]
    let doseLogs: [DoseLog]
    let refills: [RefillEvent]
    var checkIns: [DailyCheckIn] = []
    var weights: [WeightEntry] = []
    var weightUnit = WeightUnit.kg
    var calculatorResults: [CalculatorResult] = []
    var sideEffects: [SideEffectEntry] = []

    /// One file per kind, from a snapshot of the store.
    @MainActor
    static func all(from store: MedicineStore) -> [DataExportFile] {
        Kind.allCases.map {
            DataExportFile(
                kind: $0, medicines: store.medicines, doseLogs: store.doseLogs, refills: store.refills,
                checkIns: store.checkIns, weights: store.weights, weightUnit: store.settings.weightUnit,
                calculatorResults: store.calculatorResults, sideEffects: store.sideEffects
            )
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            SentTransferredFile(try await file.write())
        }
    }

    @MainActor
    private func write() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: kind.fileName)
        try? FileManager.default.removeItem(at: url)
        // A byte-order mark so Excel reads accents and symbols correctly.
        try ("\u{FEFF}" + csv()).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: CSV

    @MainActor
    private func csv() -> String {
        switch kind {
        case .doses: dosesCSV()
        case .medicines: medicinesCSV()
        case .refills: refillsCSV()
        case .health: healthCSV()
        case .calculators: calculatorsCSV()
        case .sideEffects: sideEffectsCSV()
        }
    }

    private func dosesCSV() -> String {
        let names = Dictionary(medicines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let rows = doseLogs
            .sorted { ($0.day, $0.time.minutesSinceMidnight) > ($1.day, $1.time.minutesSinceMidnight) }
            .map { log -> [String] in
                let medicine = names[log.medicineID]
                return [
                    Self.day(log.day),
                    log.time.label,
                    medicine?.name ?? "Deleted medicine",
                    medicine.map { $0.unit.format(log.units) } ?? "\(log.units)",
                    log.isTaken ? "Taken" : "Missed",
                    log.takenAt.map(Self.dateTime) ?? "",
                    log.site?.title ?? "",
                ]
            }
        return Self.table(header: ["Date", "Scheduled time", "Medicine", "Amount", "Status", "Taken at", "Injection site"], rows: rows)
    }

    private func medicinesCSV() -> String {
        let rows = medicines.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { medicine -> [String] in
            [
                medicine.name,
                medicine.brandName,
                medicine.strength,
                medicine.typeTitle,
                medicine.frequency.title,
                medicine.scheduleTimes,
                medicine.unit.format(medicine.unitsPerIntake),
                "\(medicine.stock)",
                "\(medicine.daysLeft)",
                medicine.reason,
                medicine.instructions,
                Self.day(medicine.createdAt),
            ]
        }
        return Self.table(
            header: ["Medicine", "Brand", "Strength", "Type", "Days", "Times", "Each dose", "In stock", "Days left", "For", "Instructions", "Added"],
            rows: rows
        )
    }

    private func refillsCSV() -> String {
        let rows = refills.sorted { $0.date > $1.date }.map { refill -> [String] in
            [Self.day(refill.date), refill.medicineName, "\(refill.amount)", "\(refill.lastsDays)"]
        }
        return Self.table(header: ["Date", "Medicine", "Amount", "Lasts (days)"], rows: rows)
    }

    /// One row per day with a mood or a weigh-in, newest first.
    private func healthCSV() -> String {
        let moods = Dictionary(checkIns.map { ($0.day, $0.mood) }, uniquingKeysWith: { _, last in last })
        let kilos = Dictionary(weights.map { ($0.day, $0.kilograms) }, uniquingKeysWith: { _, last in last })
        let days = Set(moods.keys).union(kilos.keys).sorted(by: >)
        let rows = days.map { day -> [String] in
            [
                Self.day(day),
                moods[day]?.title ?? "",
                kilos[day].map { weightUnit.value(fromKilograms: $0).formatted(.number.precision(.fractionLength(1)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))) } ?? "",
            ]
        }
        return Self.table(header: ["Date", "Mood", "Weight (\(weightUnit.rawValue))"], rows: rows)
    }

    private func calculatorsCSV() -> String {
        let rows = calculatorResults.sorted { $0.day > $1.day }.map { result -> [String] in
            [
                Self.day(result.day),
                result.kind.title,
                result.kind == .bmi
                    ? result.value.formatted(.number.precision(.fractionLength(1)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
                    : "\(Int(result.value.rounded()))",
                result.kind == .bmi ? "BMI" : "kcal/day",
                result.weightKg.map { weightUnit.value(fromKilograms: $0).formatted(.number.precision(.fractionLength(1)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))) } ?? "",
                result.protein.map(String.init) ?? "",
                result.carbs.map(String.init) ?? "",
                result.fat.map(String.init) ?? "",
            ]
        }
        return Self.table(header: ["Date", "Calculator", "Result", "Unit", "Weight (\(weightUnit.rawValue))", "Protein (g)", "Carbs (g)", "Fat (g)"], rows: rows)
    }

    private func sideEffectsCSV() -> String {
        let names = Dictionary(medicines.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let rows = sideEffects.sorted { $0.date > $1.date }.map { entry -> [String] in
            [
                Self.dateTime(entry.date),
                entry.kind.title,
                entry.severity.title,
                entry.medicineID.flatMap { names[$0] } ?? "",
                entry.site?.title ?? "",
                entry.note,
            ]
        }
        return Self.table(header: ["Date", "Side effect", "Severity", "Medicine", "Injection site", "Note"], rows: rows)
    }

    // MARK: Formatting

    private static func table(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes a field that holds a comma, quote or line break.
    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// "2026-11-16" — sorts correctly in any spreadsheet, in local time.
    private static func day(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }

    /// "2026-11-16 20:03", 24-hour so it never needs AM/PM.
    private static func dateTime(_ date: Date) -> String { formatter("yyyy-MM-dd HH:mm").string(from: date) }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}
