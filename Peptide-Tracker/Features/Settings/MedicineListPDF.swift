import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// "Export medicine list" — a one-page PDF of every medicine, its doses and
/// supply, for doctor visits. Rendered only when the share sheet asks for it.
struct MedicineListPDF: Transferable {
    let medicines: [Medicine]
    let pharmacyName: String
    let date: Date

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { document in
            SentTransferredFile(try await document.render())
        }
        .suggestedFileName("Medicine list.pdf")
    }

    @MainActor
    private func render() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "Medicine list.pdf")
        let page = CGSize(width: 595, height: 842) // A4 in points
        let renderer = ImageRenderer(content: MedicineListPage(document: self).frame(width: page.width))
        renderer.proposedSize = ProposedViewSize(width: page.width, height: nil)

        var failure: Error?
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: page.width, height: max(size.height, page.height)))
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
                failure = CocoaError(.fileWriteUnknown)
                return
            }
            context.beginPDFPage(nil)
            // Content draws from the top of the page.
            context.translateBy(x: 0, y: box.height - size.height)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        if let failure { throw failure }
        return url
    }
}

private struct MedicineListPage: View {
    let document: MedicineListPDF

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Medicines").font(.system(size: 26, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    header("Medicine")
                    header("Dose")
                    header("Times")
                    header("Left")
                    header("Runs out")
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(document.medicines) { medicine in
                    GridRow(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(medicine.name).font(.system(size: 12, weight: .semibold))
                            Text([medicine.strength, medicine.type.title].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        cell("\(medicine.unit.format(medicine.unitsPerIntake)), \(medicine.scheduleTitle.lowercased())")
                        cell(medicine.scheduleList)
                        cell(medicine.unit.format(medicine.stock))
                        cell(medicine.runOutDate(now: document.date).weekdayDayMonth)
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

    private var subtitle: String {
        let pharmacy = document.pharmacyName.trimmingCharacters(in: .whitespaces)
        let date = document.date.formatted(.dateTime.day().month(.wide).year())
        return pharmacy.isEmpty ? "As of \(date)" : "As of \(date) · Pharmacy: \(pharmacy)"
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).textCase(.uppercase).foregroundStyle(.secondary)
    }

    private func cell(_ text: String) -> some View {
        Text(text).font(.system(size: 12))
    }
}
