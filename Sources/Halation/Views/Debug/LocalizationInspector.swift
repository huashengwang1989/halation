import SwiftUI

/// Debug ▸ Localisations (i18n). English only, like the rest of the debug menu.
///
/// A read-only view of every localized string in the app, so a missing or
/// obviously-wrong translation can be found without grepping translations.py.
///
/// Built by hand rather than with `Table`, which cannot freeze columns. The two
/// panes — frozen key/English on the left, the rest inside a horizontal scroll
/// view — stay aligned only because every row is the same fixed height, so
/// nothing here may size itself to its content.
struct LocalizationInspector: View {
    private enum SortColumn: Equatable {
        case key
        case language(String)
    }

    private static let rowsPerPage = 20
    private static let rowHeight: CGFloat = 30
    private static let keyWidth: CGFloat = 260
    private static let valueWidth: CGFloat = 240
    private static let noteWidth: CGFloat = 70
    private static let frozenWidth: CGFloat = keyWidth + valueWidth

    private let catalog = TranslationCatalog.shared

    @State private var search = ""
    @State private var sortColumn: SortColumn = .key
    @State private var ascending = true
    @State private var page = 0
    @State private var openNote: String?

    /// English is frozen beside the key, so the scrolling pane holds the rest.
    private var scrollingLanguages: [String] {
        catalog.languages.filter { $0 != "en" }
    }

    /// Both panes are pinned to exactly the width of their columns, and that is
    /// load-bearing rather than tidiness.
    ///
    /// `headerRow` ends in a `Divider()`, and a divider inside a VStack asks for
    /// *infinite* width. So each pane grew to whatever width it was offered and
    /// centred its fixed-width rows inside itself, which showed up as a margin
    /// to the left of the Key column and a matching gap before the first
    /// scrolling language — and, because the frozen pane had eaten the space,
    /// the last language and the Notes column were pushed off the right edge
    /// entirely. Fixing the widths pins the rows to the leading edge and gives
    /// the scrolling pane back the room it needs.
    private var scrollingWidth: CGFloat {
        CGFloat(scrollingLanguages.count) * Self.valueWidth + Self.noteWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
            Divider()
            if visibleEntries.isEmpty {
                emptyState
            } else {
                grid
            }
            Divider()
            paginationBar
        }
        .frame(minWidth: 880, minHeight: 640)
    }

    // MARK: - Filtering, sorting, paging

    private var filteredEntries: [TranslationCatalog.Entry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalog.entries }
        return catalog.entries.filter {
            $0.searchHaystack.localizedCaseInsensitiveContains(query)
        }
    }

    private var sortedEntries: [TranslationCatalog.Entry] {
        let sorted = filteredEntries.sorted { left, right in
            let a: String, b: String
            switch sortColumn {
            case .key:
                a = left.key; b = right.key
            case .language(let code):
                a = left.value(code); b = right.value(code)
            }
            // localizedStandardCompare is the Finder's ordering: case-insensitive,
            // and it sorts embedded numbers by value rather than by digit.
            let result = a.localizedStandardCompare(b)
            // Ties break on the key, or equal values would shuffle between
            // renders and the table would look unstable while scrolling.
            if result == .orderedSame { return left.key < right.key }
            return result == .orderedAscending
        }
        return ascending ? sorted : sorted.reversed()
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(sortedEntries.count) / Double(Self.rowsPerPage))))
    }

    private var visibleEntries: [TranslationCatalog.Entry] {
        let all = sortedEntries
        // `page` is clamped rather than trusted: a search that shrinks the
        // results can leave it past the end before the binding resets it.
        let start = min(max(0, page), pageCount - 1) * Self.rowsPerPage
        return Array(all[start..<min(start + Self.rowsPerPage, all.count)])
    }

    // MARK: - Chrome

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search keys, translations and notes", text: $search)
                .textFieldStyle(.plain)
                .onChange(of: search) { page = 0 }
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(sortedEntries.count) of \(catalog.entries.count) keys")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Nothing matches “\(search)”").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var paginationBar: some View {
        HStack(spacing: 12) {
            Button {
                page = max(0, page - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(page <= 0)

            Text("Page \(min(page, pageCount - 1) + 1) of \(pageCount)")
                .font(.callout)
                .monospacedDigit()
                .frame(minWidth: 110)

            Button {
                page = min(pageCount - 1, page + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(page >= pageCount - 1)

            Spacer()
            Text("\(Self.rowsPerPage) rows per page")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - The grid

    private var grid: some View {
        HStack(spacing: 0) {
            // Frozen. Outside the horizontal scroll view, so it stays put.
            VStack(spacing: 0) {
                headerRow {
                    headerCell("Key", width: Self.keyWidth, sort: .key)
                    headerCell("en", width: Self.valueWidth, sort: .language("en"),
                               help: languageName("en"))
                }
                ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                    row(striped: index.isMultiple(of: 2)) {
                        cell(entry.key, width: Self.keyWidth, monospaced: true)
                        cell(entry.value("en"), width: Self.valueWidth)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: Self.frozenWidth, alignment: .leading)

            Divider()

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    headerRow {
                        ForEach(scrollingLanguages, id: \.self) { code in
                            headerCell(code, width: Self.valueWidth,
                                       sort: .language(code),
                                       help: languageName(code))
                        }
                        // Not sortable: the column holds an icon, not a value.
                        Text("Notes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: Self.noteWidth, height: Self.rowHeight)
                    }
                    ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                        row(striped: index.isMultiple(of: 2)) {
                            ForEach(scrollingLanguages, id: \.self) { code in
                                cell(entry.value(code), width: Self.valueWidth)
                            }
                            noteCell(entry)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: scrollingWidth, alignment: .leading)
            }
            .frame(maxWidth: scrollingWidth)

            Spacer(minLength: 0)
        }
    }

    private func headerRow(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) { content() }
                .frame(height: Self.rowHeight)
                .background(.quaternary.opacity(0.4))
            Divider()
        }
    }

    private func row(striped: Bool, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 0) { content() }
            .frame(height: Self.rowHeight)
            .background(striped ? Color.primary.opacity(0.035) : .clear)
    }

    private func headerCell(_ title: String, width: CGFloat,
                            sort: SortColumn, help: String? = nil) -> some View {
        Button {
            if sortColumn == sort {
                ascending.toggle()
            } else {
                sortColumn = sort
                ascending = true
            }
            page = 0
        } label: {
            HStack(spacing: 3) {
                Text(title).font(.caption.weight(.semibold))
                if sortColumn == sort {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: width, height: Self.rowHeight, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help ?? "Sort by \(title)")
    }

    /// One line, always. The full text is in the tooltip: letting a cell grow to
    /// fit would break the alignment the two panes depend on.
    private func cell(_ text: String, width: CGFloat, monospaced: Bool = false) -> some View {
        Text(text)
            .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
            .foregroundStyle(text.isEmpty ? .tertiary : .primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .textSelection(.enabled)
            .padding(.horizontal, 8)
            .frame(width: width, height: Self.rowHeight, alignment: .leading)
            .help(text)
    }

    @ViewBuilder
    private func noteCell(_ entry: TranslationCatalog.Entry) -> some View {
        Group {
            if entry.hasNote {
                Button {
                    openNote = entry.key
                } label: {
                    Image(systemName: entry.level.symbolName)
                        .foregroundStyle(entry.level == .warning ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: Binding(
                    get: { openNote == entry.key },
                    set: { if !$0 { openNote = nil } })) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: entry.level.symbolName)
                                .foregroundStyle(entry.level == .warning ? .orange : .secondary)
                            Text(entry.key)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.note)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .frame(width: 320)
                }
            } else {
                // Deliberately blank: an icon here would suggest a note exists.
                Color.clear
            }
        }
        .frame(width: Self.noteWidth, height: Self.rowHeight)
    }

    private func languageName(_ code: String) -> String {
        Locale(identifier: "en").localizedString(forIdentifier: code) ?? code
    }
}
