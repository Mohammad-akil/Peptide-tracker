import Foundation

/// The app's pages on its website (the peptide-tracker-web repo).
/// Update `website` if the Vercel domain changes.
enum AppLinks {
    static let website = URL(string: "https://doseday.vercel.app")!
    static let privacyPolicy = website.appending(path: "privacy")
    static let termsOfUse = website.appending(path: "terms")
    static let support = website.appending(path: "support")
}
