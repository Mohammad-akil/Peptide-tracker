import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// "Share as PDF" on the report: the period's rate, counts and each
/// medicine's rate on one page, for doctor visits.
struct AdherenceReportPDF: Transferable {
    let report: AdherenceReport
    let personName: String?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { document in
            SentTransferredFile(try await document.render())
        }
        .suggestedFileName("Adherence report.pdf")
    }

    @MainActor
    private func render() throws -> URL {
        try PDFRendering.render(AdherenceReportPage(document: self), fileName: "Adherence report.pdf")
    }
}

private struct AdherenceReportPage: View {
    let document: AdherenceReportPDF
    private var report: AdherenceReport { document.report }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Adherence report").font(.system(size: 26, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }

            HStack(spacing: 28) {
                figure((report.rate ?? 0).percentLabel, "of doses taken")
                figure("\(report.taken)", "taken")
                figure("\(report.missed)", "missed")
                figure("\(report.streak)", report.streak == 1 ? "day streak" : "days streak")
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
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.black)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    /// "Mohammad Akil · Last 30 days, to 19 October 2026"
    private var subtitle: String {
        let range = "Last \(report.period.days) days, to \(report.now.formatted(.dateTime.day().month(.wide).year()))"
        return [document.personName, range].compactMap { $0 }.joined(separator: " · ")
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .bold)).monospacedDigit()
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).textCase(.uppercase).foregroundStyle(.secondary)
    }

    private func cell(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).monospacedDigit()
    }
}
