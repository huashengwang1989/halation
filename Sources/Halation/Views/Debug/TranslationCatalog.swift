import Foundation

/// Every localized string in the app, with its translations and its note.
///
/// Loaded from the JSON that Scripts/build_strings.py writes beside the .lproj
/// folders. The .strings files themselves cannot serve this: each carries one
/// language, and the notes are C comments in them, which nothing reads back.
struct TranslationCatalog: Decodable {
    /// How much attention a note is asking for. See Scripts/translations.py.
    enum Level: String, Decodable {
        /// Context a translator needs: which sense of an ambiguous word is
        /// meant, and where it appears.
        case info
        /// The key translates into the five languages shipped today, but the
        /// way it is assembled will not generalise — a plural count, a noun
        /// injected into a sentence, or a phrase built at runtime.
        case warning

        var symbolName: String {
            switch self {
            case .info: "info.circle"
            case .warning: "exclamationmark.triangle.fill"
            }
        }
    }

    struct Entry: Decodable, Identifiable {
        let key: String
        let values: [String: String]
        let note: String
        let level: Level

        var id: String { key }
        var hasNote: Bool { !note.isEmpty }

        func value(_ language: String) -> String { values[language] ?? "" }

        /// Everything the search field looks through: the key, every
        /// translation, and the note.
        var searchHaystack: String {
            ([key] + values.values + [note]).joined(separator: "\u{1}")
        }
    }

    let languages: [String]
    let entries: [Entry]

    static let empty = TranslationCatalog(languages: [], entries: [])

    /// Decoded once. The file is a few hundred KB and never changes at runtime,
    /// so re-reading it per keystroke in the search field would be waste.
    static let shared: TranslationCatalog = {
        guard let url = Bundle.module.url(forResource: "translation-catalog",
                                          withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(TranslationCatalog.self, from: data)
        else { return .empty }
        return decoded
    }()
}
