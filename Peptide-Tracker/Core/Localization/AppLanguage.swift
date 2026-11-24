import Foundation
import ObjectiveC
import SwiftUI

/// The languages Doseday ships, plus the runtime switch that makes a choice
/// take effect at once instead of after a relaunch (the same approach as
/// Plates). Widgets run in their own process and follow the device language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case englishUK = "en-GB"
    case englishAustralia = "en-AU"
    case englishCanada = "en-CA"
    case german = "de"
    case japanese = "ja"
    case french = "fr"
    case frenchCanada = "fr-CA"
    case spanish = "es"
    case spanishMexico = "es-MX"
    case portuguese = "pt-BR"
    case italian = "it"
    case korean = "ko"
    case arabic = "ar"
    case turkish = "tr"
    case chineseTraditional = "zh-Hant"
    case indonesian = "id"
    case hindi = "hi"
    case russian = "ru"
    case chineseSimplified = "zh-Hans"

    /// `@AppStorage` key; empty means "follow the device language".
    nonisolated static let storageKey = "appLanguage"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    /// iOS only flips layout direction at launch, so the app root sets this
    /// explicitly to make an in-app switch to Arabic mirror at once.
    var layoutDirection: LayoutDirection {
        Locale.Language(identifier: rawValue).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    /// Each language's name in itself, so people can find theirs even when
    /// the app is in a language they can't read.
    var nativeName: String {
        switch self {
        case .english: "English (US)"
        case .englishUK: "English (UK)"
        case .englishAustralia: "English (Australia)"
        case .englishCanada: "English (Canada)"
        case .german: "Deutsch"
        case .japanese: "日本語"
        case .french: "Français"
        case .frenchCanada: "Français (Canada)"
        case .spanish: "Español (España)"
        case .spanishMexico: "Español (México)"
        case .portuguese: "Português (Brasil)"
        case .italian: "Italiano"
        case .korean: "한국어"
        case .arabic: "العربية"
        case .turkish: "Türkçe"
        case .chineseTraditional: "繁體中文"
        case .indonesian: "Bahasa Indonesia"
        case .hindi: "हिन्दी"
        case .russian: "Русский"
        case .chineseSimplified: "简体中文"
        }
    }

    /// The language's name in the app's current language, under the native one.
    var localizedName: String {
        Locale.current.localizedString(forIdentifier: rawValue) ?? nativeName
    }

    var shortCode: String { rawValue.prefix(2).uppercased() }

    var flag: String {
        switch self {
        case .english: "🇺🇸"
        case .englishUK: "🇬🇧"
        case .englishAustralia: "🇦🇺"
        case .englishCanada: "🇨🇦"
        case .german: "🇩🇪"
        case .japanese: "🇯🇵"
        case .french: "🇫🇷"
        case .frenchCanada: "🇨🇦"
        case .spanish: "🇪🇸"
        case .spanishMexico: "🇲🇽"
        case .portuguese: "🇧🇷"
        case .italian: "🇮🇹"
        case .korean: "🇰🇷"
        case .arabic: "🇸🇦"
        case .turkish: "🇹🇷"
        case .chineseTraditional: "🇹🇼"
        case .indonesian: "🇮🇩"
        case .hindi: "🇮🇳"
        case .russian: "🇷🇺"
        case .chineseSimplified: "🇨🇳"
        }
    }

    /// The saved choice, else the closest match for the device.
    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey), let saved = AppLanguage(rawValue: raw) {
            return saved
        }
        return deviceDefault
    }

    static var deviceDefault: AppLanguage {
        for identifier in Locale.preferredLanguages {
            if let exact = allCases.first(where: { $0.rawValue == identifier }) { return exact }
            let language = Locale.Language(identifier: identifier)
            let code = language.languageCode?.identifier ?? identifier
            // Script first, so zh-TW / zh-HK land on zh-Hant.
            if let script = Locale.Language(identifier: language.maximalIdentifier).script?.identifier,
               let match = allCases.first(where: { $0.rawValue == "\(code)-\(script)" }) {
                return match
            }
            // Region next (en-GB, fr-CA, es-MX), then the language alone.
            if let region = language.region?.identifier,
               let match = allCases.first(where: { $0.rawValue == "\(code)-\(region)" }) {
                return match
            }
            if let match = allCases.first(where: { $0.rawValue == code || $0.rawValue.hasPrefix(code + "-") }) {
                return match
            }
        }
        return .english
    }

    /// Re-points `Bundle.main` lookups (`String(localized:)`, `Text("…")`) at
    /// the chosen language's `.lproj` for the rest of this run, and stores it
    /// so the next launch starts in the same language.
    static func apply(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")

        object_setClass(Bundle.main, LanguageBundle.self)
        // A regional English without its own strings falls back to the base.
        let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:))
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Call once at launch so a previously chosen language is active before
    /// any view reads a localized string.
    static func applyStoredChoice() {
        guard let raw = UserDefaults.standard.string(forKey: storageKey), let saved = AppLanguage(rawValue: raw) else { return }
        apply(saved)
    }
}

nonisolated(unsafe) private var languageBundleKey: UInt8 = 0

private nonisolated final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &languageBundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
