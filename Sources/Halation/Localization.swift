import Foundation
import Observation
import SwiftUI

/// The languages the interface is translated into.
///
/// Regional variants are deliberately absent: `en-GB`, `de-AT` and `zh-Hant-HK`
/// all resolve onto these through Foundation's own matching, so there is nothing
/// to maintain per region.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case chineseTraditional = "zh-Hant"
    case chineseSimplified = "zh-Hans"
    case german = "de"
    case arabic = "ar"
    case japanese = "ja"
    case korean = "ko"
    case thai = "th"
    case cantonese = "yue-Hant"
    case singlish = "en-SG"

    var id: String { rawValue }

    /// Whether "Follow system" may land on this language by itself.
    ///
    /// Singlish is false, and that is the whole reason this property exists.
    /// Foundation matches the closest tag it can, so shipping `en-SG` would hand
    /// Singlish to everyone in Singapore whose language list mentions it — and
    /// someone who set English (Singapore) asked for English spelling, not for
    /// a colloquial register. It stays reachable by picking it in Settings.
    ///
    /// Cantonese is true: a reader whose system asks for Cantonese means it.
    var matchesSystemPreference: Bool {
        self != .singlish
    }

    /// Shown in its own language, which is what a language picker should do —
    /// someone who cannot read the current UI still needs to find their own.
    var endonym: String {
        switch self {
        case .english: "English"
        case .chineseTraditional: "繁體中文"
        case .chineseSimplified: "简体中文"
        case .german: "Deutsch"
        case .arabic: "العربية"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .thai: "ไทย"
        case .cantonese: "廣東話"
        case .singlish: "Singlish"
        }
    }

    /// Whether this language mirrors the interface. Only used to decide how
    /// emphatically to nudge the user towards a relaunch.
    var isRightToLeft: Bool {
        Locale.Language(identifier: rawValue).characterDirection == .rightToLeft
    }
}

/// What the user picked: a specific language, or whatever the system says.
enum LanguagePreference: Hashable, Sendable {
    case system
    case explicit(AppLanguage)

    var storedValue: String {
        switch self {
        case .system: "system"
        case .explicit(let language): language.rawValue
        }
    }

    init(storedValue: String) {
        if let language = AppLanguage(rawValue: storedValue) {
            self = .explicit(language)
        } else {
            self = .system
        }
    }
}

/// Resolves the interface language and serves its strings.
///
/// Strings are read from an explicitly loaded `.lproj` bundle rather than through
/// the process's own localization, so our own text changes the moment the user
/// picks a language. The chrome AppKit owns — the menu bar, and the mirroring a
/// right-to-left language needs — is fixed at launch from `AppleLanguages`, so we
/// write that too and offer a relaunch.
@MainActor
@Observable
final class Localization {
    static let shared = Localization()

    static let defaultsKey = "interfaceLanguage"

    private(set) var preference: LanguagePreference
    private(set) var resolved: AppLanguage
    /// Bumped whenever the language changes, so the view tree can be rebuilt and
    /// re-read every string.
    private(set) var generation = 0
    /// Set while the chosen language differs from the one this process started
    /// with, so only a fresh launch can finish applying it.
    private(set) var needsRelaunch = false
    /// Set when that relaunch will also flip the interface between left-to-right
    /// and right-to-left. Worth saying out loud; the rest of the time, mentioning
    /// mirroring to someone switching between two left-to-right languages only
    /// raises a question they did not have.
    private(set) var directionWillChange = false

    /// What the app was launched as. Going back to it clears the relaunch note,
    /// since at that point nothing is pending.
    private let launchPreference: LanguagePreference

    private var bundle: Bundle

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? "system"
        let preference = LanguagePreference(storedValue: stored)
        let resolved = Self.resolve(preference)
        self.preference = preference
        self.launchPreference = preference
        self.resolved = resolved
        self.bundle = Self.bundle(for: resolved)
        Self.activeBundle = bundle
        Self.currentLocale = Locale(identifier: resolved.rawValue)
    }

    /// The language a preference actually produces.
    ///
    /// For `.system`, Foundation matches the user's ordered preferences against
    /// what we ship: `en-GB` lands on English, `zh-Hant-HK` on Traditional
    /// Chinese, and anything unsupported falls back to English.
    static func resolve(_ preference: LanguagePreference) -> AppLanguage {
        switch preference {
        case .explicit(let language):
            return language
        case .system:
            let supported = AppLanguage.allCases
                .filter(\.matchesSystemPreference).map(\.rawValue)
            let matched = Bundle.preferredLocalizations(
                from: supported, forPreferences: systemPreferredLanguages).first
            return matched.flatMap(AppLanguage.init(rawValue:)) ?? .english
        }
    }

    /// The languages the *system* asks for, in order.
    ///
    /// Read out of the global domain rather than from `Locale.preferredLanguages`,
    /// which answers with the app-domain `AppleLanguages` we write ourselves the
    /// moment we write one. Going through `Locale` made "Follow system" rename
    /// itself to whichever language the user had just picked — so on an English
    /// Mac, choosing Chinese relabelled the option "跟随系统（简体中文）". What the
    /// system asks for only changes when the user changes it in System Settings.
    static var systemPreferredLanguages: [String] {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        if let languages = global?["AppleLanguages"] as? [String], !languages.isEmpty {
            return languages
        }
        // Nothing in the global domain only happens before the Mac has been set
        // up; at that point our own override cannot exist yet either.
        return Locale.preferredLanguages
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .module }
        return bundle
    }

    /// The bundle `localized(_:)` reads from. Static so the lookup does not have
    /// to reach the observable from every call site.
    nonisolated(unsafe) fileprivate static var activeBundle: Bundle = .module

    func set(_ preference: LanguagePreference) {
        guard preference != self.preference else { return }
        self.preference = preference
        UserDefaults.standard.set(preference.storedValue, forKey: Self.defaultsKey)
        // AppKit reads these once, at launch. `AppleLanguages` picks the language
        // of the menu bar and every other string AppKit supplies itself.
        //
        // Mirroring needs the second key. A per-app `AppleLanguages` override does
        // *not* flip the interface to right-to-left — measured, not assumed: with
        // it alone the menu bar came up in Arabic while the window, its toolbar and
        // the traffic lights all stayed left-to-right. `AppleTextDirection` is the
        // switch that actually moves them, and it is the one Xcode sets for its
        // right-to-left pseudolanguage.
        let defaults = UserDefaults.standard
        switch preference {
        case .system:
            // Clear both, so the app inherits the system's language *and* its
            // direction — right or left — exactly as any unmodified app would.
            defaults.removeObject(forKey: "AppleLanguages")
            defaults.removeObject(forKey: "AppleTextDirection")
        case .explicit(let language):
            defaults.set([language.rawValue], forKey: "AppleLanguages")
            // Written explicitly in both directions rather than cleared for the
            // left-to-right ones. The two conditions are ANDed, not XORed —
            // measured: `ar` + NO is left-to-right, `en` + YES is left-to-right,
            // only `ar` + YES mirrors — so picking Arabic on an Arabic system
            // cannot double-flip back. But clearing the key would leave an
            // English interface inheriting a right-to-left system's mirroring,
            // which is why `false` is written rather than the key removed.
            defaults.set(language.isRightToLeft, forKey: "AppleTextDirection")
        }
        needsRelaunch = preference != launchPreference
        directionWillChange = Self.isRightToLeft(after: preference) != Self.processIsRightToLeft
        resolved = Self.resolve(preference)
        bundle = Self.bundle(for: resolved)
        Self.activeBundle = bundle
        Self.currentLocale = Locale(identifier: resolved.rawValue)
        generation += 1
    }

    /// The locale every formatter in the app should use.
    ///
    /// Foundation's formatters read `Locale.current`, which follows the process,
    /// not the bundle we swap at runtime. Without this a language change left
    /// relative dates and number units in the previous language until the next
    /// launch — "2h ago" sitting under a Chinese interface.
    /// Seeded in `init`, alongside the string bundle, so the two never disagree.
    nonisolated(unsafe) private(set) static var currentLocale = Locale(identifier: "en")

    /// Whether the window is mirrored right now.
    static var processIsRightToLeft: Bool {
        NSApp?.userInterfaceLayoutDirection == .rightToLeft
    }

    /// Whether a preference would mirror the window once the app restarts.
    static func isRightToLeft(after preference: LanguagePreference) -> Bool {
        switch preference {
        case .explicit(let language):
            return language.isRightToLeft
        case .system:
            return systemIsRightToLeft
        }
    }

    /// The direction the system itself asks for.
    static var systemIsRightToLeft: Bool {
        guard let language = systemPreferredLanguages.first else { return false }
        return Locale.Language(identifier: language).characterDirection == .rightToLeft
    }

    /// Quits and reopens, so AppKit picks up the new `AppleLanguages`.
    ///
    /// The new instance is started before this one exits, so the app does not
    /// blink out of the Dock in between.
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL,
                                           configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    /// What a `.system` preference currently resolves to, for the picker's label.
    var systemResolution: AppLanguage { Self.resolve(.system) }
}

/// Looks up a UI string.
///
/// Keys are semantic (`compose.generate.button`) rather than English text, so the
/// same word can be translated differently where context demands it — a "Rate"
/// button and a "rate" measurement are not the same word in most languages.
func loc(_ key: String, _ arguments: CVarArg...) -> String {
    let format = Localization.activeBundle.localizedString(forKey: key, value: nil, table: nil)
    return arguments.isEmpty ? format : String(format: format, arguments: arguments)
}
