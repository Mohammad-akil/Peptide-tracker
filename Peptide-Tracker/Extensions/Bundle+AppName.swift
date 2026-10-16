import Foundation

extension Bundle {
    /// The name under the app icon.
    var appName: String {
        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)?.replacingOccurrences(of: "-", with: " ")
            ?? "Refills"
    }
}
