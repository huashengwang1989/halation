import SwiftUI

/// Debug ▸ Localisations (i18n) ▸ Glossary. English only, like the rest of the
/// debug menu.
///
/// The terms that have more than one defensible translation, and which one this
/// project uses. The same list `make check` enforces, read from the same
/// catalogue — so what is on screen cannot disagree with what the build allows.
///
/// Worth showing rather than leaving in a Python file: the drift it prevents is
/// only visible when two surfaces are read side by side, which is exactly what
/// nobody does while editing one string.
struct GlossaryView: View {
    private static let languageWidth: CGFloat = 110
    private static let useWidth: CGFloat = 220

    let catalog: TranslationCatalog
    @Binding var search: String

    private var terms: [TranslationCatalog.Term] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalog.glossary }
        return catalog.glossary.filter {
            $0.searchHaystack.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        if catalog.glossary.isEmpty {
            empty("No glossary in this build's catalogue.")
        } else if terms.isEmpty {
            empty("No term matches “\(search)”.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(terms) { term in
                        section(for: term)
                    }
                    footnote
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func avoided(_ term: TranslationCatalog.Term, _ language: String) -> [String] {
        (term.avoid[language] ?? [])
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Pieces

    private func section(for term: TranslationCatalog.Term) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(term.name)
                    .font(.title3.weight(.semibold))
                    .textSelection(.enabled)
                if !term.sense.isEmpty {
                    Text(term.sense)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Grid(alignment: .leadingFirstTextBaseline,
                 horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Language").gridColumnAlignment(.leading)
                    Text("Use")
                    Text("Not")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Divider().gridCellUnsizedAxes(.horizontal).gridCellColumns(3)

                ForEach(term.languages(in: catalog.languages), id: \.self) { language in
                    GridRow {
                        Text(language)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: Self.languageWidth, alignment: .leading)
                        Text(term.canonical[language] ?? "—")
                            .frame(width: Self.useWidth, alignment: .leading)
                            .textSelection(.enabled)
                        // Struck through rather than merely listed: these are
                        // not alternatives, they are what the build rejects.
                        // Trimmed for display only. A spelling is often stored
                        // with a leading space, which is what keeps it from
                        // matching inside a longer word — but showing that space
                        // reads as a typo.
                        Text(avoided(term, language).joined(separator: ", "))
                            .strikethrough(!avoided(term, language).isEmpty)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var footnote: some View {
        Text("Edited in GLOSSARY in Scripts/translations.py, checked by "
             + "`make check`, and carried here in translation-catalog.json. "
             + "A term belongs here the first time a second translation of it "
             + "appears, not the first time someone notices.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private func empty(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
