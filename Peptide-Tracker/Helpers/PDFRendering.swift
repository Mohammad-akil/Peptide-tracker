import SwiftUI

/// Renders a SwiftUI page into a one-page A4-wide PDF in the temporary
/// folder, growing taller than A4 when the content needs it. Shared by the
/// medicine list and the adherence report.
@MainActor
enum PDFRendering {
    static let pageSize = CGSize(width: 595, height: 842) // A4 in points

    static func render<Page: View>(_ page: Page, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: fileName)
        let renderer = ImageRenderer(content: page.frame(width: pageSize.width))
        renderer.proposedSize = ProposedViewSize(width: pageSize.width, height: nil)

        var failure: Error?
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: pageSize.width, height: max(size.height, pageSize.height)))
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
