import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// "Share as PDF" on the report: the period's rate, counts and each
/// medicine's rate on one page, for doctor visits.
struct AdherenceReportPDF: Transferable {
    let report: AdherenceReport
    let personName: String?
    /// Side effects, weight, mood and injection sites over the same days.
    var health: VisitHealthSummary?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { document in
            SentTransferredFile(try await document.render())
        }
        .suggestedFileName(String(localized: "Doctor visit report.pdf"))
    }

    @MainActor
    private func render() throws -> URL {
        try PDFRendering.render(AdherenceReportPage(document: self), fileName: String(localized: "Doctor visit report.pdf"))
    }
}

private struct AdherenceReportPage: View {
    let document: AdherenceReportPDF
    private var report: AdherenceReport { document.report }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Doctor visit report").font(.system(size: 26, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }

            HStack(spacing: 28) {
                figure((report.rate ?? 0).percentLabel, String(localized: "of doses taken"))
                figure("\(report.taken)", "taken")
                figure("\(report.missed)", "missed")
                figure("\(report.streak)", report.streak == 1 ? String(localized: "day streak") : String(localized: "days streak"))
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    header("Medicine")
                    header("Taken")
                    header("Due")
                    header("Rate")
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(report.medicines) { entry in
                    GridRow {
                        Text(entry.medicine.name).font(.system(size: 12, weight: .semibold))
                        cell("\(entry.taken)")
                        cell("\(entry.due)")
                        cell(entry.rate.percentLabel)
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
            }

            if let health = document.health, !health.isEmpty {
                healthSections(health)
            }

            Text("A personal log kept by the patient in \(Bundle.main.appName). Not a medical record.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.black)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    /// "Mohammad Akil · Last 30 days, to 19 October 2026"
    private var subtitle: String {
        let range = String(localized: "Last \(report.period.days) days, to \(report.now.formatted(.dateTime.day().month(.wide).year()))")
        return [document.personName, range].compactMap { $0 }.joined(separator: " · ")
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .bold)).monospacedDigit()
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func healthSections(_ health: VisitHealthSummary) -> some View {
        if health.weightStart != nil || health.moodAverage != nil {
            sectionTitle("Health")
            HStack(spacing: 28) {
                if let start = health.weightStart, let end = health.weightEnd {
                    figure(health.weightUnit.format(end), String(localized: "weight now"))
                    let change = health.weightUnit.value(fromKilograms: end - start)
                    figure(String(localized: "\(change >= 0 ? "+" : "")\(change.formatted(.number.precision(.fractionLength(1)))) \(health.weightUnit.rawValue)"), "change")
                }
                if let mood = health.moodAverage {
                    figure(mood.formatted(.number.precision(.fractionLength(1))) + " / 5", String(localized: "average mood"))
                }
            }
        }

        if !health.sideEffects.isEmpty {
            sectionTitle(String(localized: "Side effects logged"))
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    header(String(localized: "Side effect"))
                    header("Times")
                    header("Worst")
                    header("Pattern")
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(health.sideEffects, id: \.kind) { line in
                    GridRow {
                        Text(line.kind.title).font(.system(size: 12, weight: .semibold))
                        cell("\(line.count)")
                        cell(line.worst.title)
                        Text(line.pattern ?? "–").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
            }
        }

        if !health.sites.isEmpty {
            sectionTitle(String(localized: "Injection sites used"))
            Text(health.sites.map { "\($0.site.title) \($0.count)×" + ($0.reactions == 0 ? "" : $0.reactions == 1 ? String(localized: " (1 reaction)") : String(localized: " (\($0.reactions) reactions)")) }.joined(separator: " · "))
                .font(.system(size: 11))
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 15, weight: .bold)).padding(.top, 6)
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).textCase(.uppercase).foregroundStyle(.secondary)
    }

    private func cell(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).monospacedDigit()
    }
}

// MARK: - Health summary

/// The health side of the doctor visit report, over the report's days:
/// side effects by kind, weight change, average mood, and injection sites.
struct VisitHealthSummary {
    struct SideEffectLine {
        let kind: SideEffectEntry.Kind
        let count: Int
        let worst: SideEffectEntry.Severity
        let pattern: String?
    }

    struct SiteLine {
        let site: InjectionSite
        let count: Int
        let reactions: Int
    }

    var sideEffects: [SideEffectLine] = []
    var weightStart: Double?
    var weightEnd: Double?
    var weightUnit = WeightUnit.kg
    var moodAverage: Double?
    var sites: [SiteLine] = []

    var isEmpty: Bool { sideEffects.isEmpty && weightStart == nil && moodAverage == nil && sites.isEmpty }

    @MainActor
    init(store: MedicineStore, days: Int, now: Date = .now) {
        let start = now.startOfDay.adding(days: -(days - 1))

        let effects = store.sideEffects.filter { $0.day >= start }
        let patterns = Dictionary(uniqueKeysWithValues: store.sideEffectPatterns().map { ($0.kind, $0) })
        sideEffects = Dictionary(grouping: effects, by: \.kind)
            .map { kind, group in
                let pattern = patterns[kind].flatMap { $0.offsetCount >= 2 ? $0.sentence : nil }
                return SideEffectLine(kind: kind, count: group.count, worst: group.map(\.severity).max() ?? .mild, pattern: pattern)
            }
            .sorted { $0.count > $1.count }

        let weights = store.weights.filter { $0.day >= start }
        if weights.count >= 1 {
            weightStart = weights.first?.kilograms
            weightEnd = weights.last?.kilograms
        }
        weightUnit = store.settings.weightUnit

        let moods = store.checkIns.filter { $0.day >= start }.map(\.mood.rawValue)
        if !moods.isEmpty { moodAverage = Double(moods.reduce(0, +)) / Double(moods.count) }

        var counts: [InjectionSite: Int] = [:]
        for log in store.doseLogs where log.isTaken && log.day >= start {
            if let site = log.site { counts[site, default: 0] += 1 }
        }
        let reactions = Dictionary(grouping: effects.compactMap(\.site), by: { $0 }).mapValues(\.count)
        sites = InjectionSite.all
            .filter { counts[$0] != nil || reactions[$0] != nil }
            .map { SiteLine(site: $0, count: counts[$0] ?? 0, reactions: reactions[$0] ?? 0) }
    }
}
