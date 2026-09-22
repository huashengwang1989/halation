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

    /// A term with more than one defensible translation, pinned to one.
    ///
    /// Mirrors `GLOSSARY` in Scripts/translations.py, which is where it is
    /// edited. Carried in this same file rather than its own so the app cannot
    /// show a glossary that has drifted from the one `make check` enforces.
    struct Term: Decodable, Identifiable {
        let term: String
        let canonical: [String: String]
        let avoid: [String: [String]]

        var id: String { term }

        /// "swap — memory paged out to disk…" splits into a heading and the
        /// sense it is pinned to, which is the part that stops an argument.
        var name: String {
            String(term.split(separator: " — ", maxSplits: 1).first ?? "")
        }

        var sense: String {
            let parts = term.components(separatedBy: " — ")
            return parts.count > 1 ? parts.dropFirst().joined(separator: " — ") : ""
        }

        /// Every language that has an opinion about this term, in catalogue
        /// order so the glossary reads in the same order as the table.
        func languages(in order: [String]) -> [String] {
            order.filter { canonical[$0] != nil || avoid[$0] != nil }
        }

        var searchHaystack: String {
            ([term] + canonical.values + avoid.values.flatMap { $0 })
                .joined(separator: "\u{1}")
        }
    }

    let languages: [String]
    let entries: [Entry]
    /// Absent from older catalogues, so it decodes to empty rather than failing
    /// and taking the whole inspector with it.
    let glossary: [Term]

    enum CodingKeys: String, CodingKey { case languages, entries, glossary }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        languages = try container.decode([String].self, forKey: .languages)
        entries = try container.decode([Entry].self, forKey: .entries)
        glossary = (try? container.decode([Term].self, forKey: .glossary)) ?? []
    }

    private init(languages: [String], entries: [Entry], glossary: [Term]) {
        self.languages = languages
        self.entries = entries
        self.glossary = glossary
    }

    static let empty = TranslationCatalog(languages: [], entries: [], glossary: [])

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
