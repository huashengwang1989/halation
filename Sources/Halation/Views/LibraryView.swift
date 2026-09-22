import AVKit
import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var app
    @State private var selection: LibraryItem.ID?
    @State private var search = ""
    @State private var width: CGFloat = 0
    /// The grid's own width, not the view's: the inspector takes a share of the
    /// latter, and the column count has to follow what the grid actually gets.
    @State private var gridWidth: CGFloat = 0
    @FocusState private var gridFocused: Bool

    private var filtered: [LibraryItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return app.library.items }
        return app.library.items.filter { $0.title.lowercased().contains(query) }
    }

    private static let tileMinimum: CGFloat = 200
    private static let tileSpacing: CGFloat = 16

    /// How many tiles `LazyVGrid`'s adaptive layout will fit, worked out the
    /// same way it does: n tiles and n-1 gaps have to fit the width, so
    /// n ≤ (width + spacing) / (minimum + spacing).
    ///
    /// Mirrored rather than measured because the grid does not report it, and
    /// an arrow key that moved by the wrong number of columns would be worse
    /// than one that did nothing.
    private var columnCount: Int {
        guard gridWidth > 0 else { return 1 }
        let usable = gridWidth - 36  // the grid's own padding, both sides
        return max(1, Int((usable + Self.tileSpacing) / (Self.tileMinimum + Self.tileSpacing)))
    }

    /// Arrow keys and WASD move the selection through the grid.
    ///
    /// Both sets, because this is a picture grid: a hand on the arrows and a
    /// hand on WASD are both natural here, and neither collides with anything —
    /// the search field takes its own keys only while it has focus.
    private func move(_ press: KeyPress, scroller: ScrollViewProxy) -> KeyPress.Result {
        let step: Int
        switch press.key {
        case .leftArrow: step = -1
        case .rightArrow: step = 1
        case .upArrow: step = -columnCount
        case .downArrow: step = columnCount
        default:
            switch press.characters.lowercased() {
            case "a": step = -1
            case "d": step = 1
            case "w": step = -columnCount
            case "s": step = columnCount
            default: return .ignored
            }
        }

        let items = filtered
        guard !items.isEmpty else { return .ignored }
        // With nothing selected, any key selects the first tile rather than
        // doing nothing: the grid has focus, so a key press should visibly land.
        guard let current = selection.flatMap({ id in items.firstIndex { $0.id == id } }) else {
            selection = items.first?.id
            scroll(to: selection, with: scroller)
            return .handled
        }
        // Clamped, not wrapped. Wrapping from the last tile to the first is a
        // surprise in a grid you are reading left to right.
        let next = min(max(0, current + step), items.count - 1)
        guard next != current else { return .handled }
        selection = items[next].id
        scroll(to: selection, with: scroller)
        return .handled
    }

    private func scroll(to id: LibraryItem.ID?, with scroller: ScrollViewProxy) {
        guard let id else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            scroller.scrollTo(id, anchor: .center)
        }
    }

    /// The inspector gives up width before the grid does, down to a readable floor.
    private var inspectorWidth: CGFloat {
        guard width > 0 else { return 320 }
        return min(380, max(260, width * 0.34))
    }

    var body: some View {
        Group {
            if app.library.items.isEmpty {
                ContentUnavailableView {
                    Label(loc("library.empty.title"), systemImage: "film.stack")
                } description: {
                    Text(loc("library.empty.detail",
                             app.library.outputFolder.path(percentEncoded: false)))
                } actions: {
                    Button(loc("queue.goCompose")) { app.section = .compose }
                        .prominentButtonStyle()
                }
            } else {
                HStack(spacing: 0) {
                    ScrollViewReader { scroller in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.tileMinimum),
                                                     spacing: Self.tileSpacing)],
                                  spacing: Self.tileSpacing) {
                            ForEach(filtered) { item in
                                // A Button rather than a tap gesture: a gesture is
                                // invisible to the keyboard and to VoiceOver, which
                                // made the whole library unreachable without a mouse.
                                Button {
                                    selection = item.id
                                } label: {
                                    LibraryTile(item: item, isSelected: selection == item.id)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.title)
                                .accessibilityValue(accessibilityDescription(of: item))
                                .accessibilityAddTraits(selection == item.id ? [.isButton, .isSelected] : .isButton)
                                .contextMenu { menu(for: item) }
                                .id(item.id)
                            }
                        }
                        .padding(18)
                    }
                    .softScrollEdge(for: .top)
                    .statusBarInset()
                    .frame(maxWidth: .infinity)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
                    // Focusable so the grid can take key presses at all, and
                    // focused on arrival so the arrows work without a click
                    // first — the selection is already visible, so a keyboard
                    // that did nothing until you clicked would be a puzzle.
                    .focusable()
                    .focusEffectDisabled()
                    .focused($gridFocused)
                    .onAppear { gridFocused = true }
                    .onKeyPress { press in move(press, scroller: scroller) }
                    }

                    // The inspector appears when something is selected and stays
                    // put; it narrows with the window rather than disappearing.
                    if let selected = filtered.first(where: { $0.id == selection }) {
                        Divider()
                        LibraryDetail(item: selected)
                            .frame(width: inspectorWidth)
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .searchable(text: $search, prompt: Text(loc("library.search")))
        .toolbar {
            ToolbarItemGroup {
                Button(loc("library.revealFolder"), systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([app.library.outputFolder])
                }
                Button(loc("common.refresh"), systemImage: "arrow.clockwise") { app.library.reload() }
            }
        }
    }

    /// Spoken after the title: what this clip is, in the order it matters.
    private func accessibilityDescription(of item: LibraryItem) -> String {
        var parts = [
            loc("library.seconds", "\(item.spec.sampling.durationSeconds)"),
            item.spec.format.deliverySize.description.replacingOccurrences(of: "×", with: " by "),
            item.spec.format.codec.label,
        ]
        if !item.exists { parts.append("file missing") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func menu(for item: LibraryItem) -> some View {
        Button(loc("library.open"), systemImage: "play.rectangle") {
            NSWorkspace.shared.open(item.videoURL)
        }
        Button(loc("queue.revealInFinder"), systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.videoURL])
        }
        Divider()
        Button(loc("library.useSettings"), systemImage: "arrow.uturn.backward") {
            app.draft = item.spec
            app.draft.sampling.seed = item.seed
            app.section = .compose
        }
        Button(loc("queue.renderAgain"), systemImage: "arrow.clockwise") {
            var spec = item.spec
            spec.sampling.seed = nil
            _ = app.engine.enqueue(spec)
            app.section = .queue
        }
        Divider()
        Button(loc("library.moveToTrash"), systemImage: "trash", role: .destructive) {
            app.library.delete(item)
        }
    }
}

private struct LibraryTile: View {
    var item: LibraryItem
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4))
                if let url = item.thumbnailURL, let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 118)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(alignment: .bottomTrailing) {
                Text(Format.clipLength(item.spec.sampling.durationSeconds))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .glassSurface(in: .capsule)
                    .padding(6)
            }

            Text(item.title)
                .font(.callout)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Text(item.spec.format.deliverySize.description)
                Text("·")
                Text(item.spec.format.codec.label)
                Spacer()
                Text(Format.relative(item.createdAt))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? AnyShapeStyle(.tint.opacity(0.16))
                                 : AnyShapeStyle(.quaternary.opacity(0.22)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
        }
        .opacity(item.exists ? 1 : 0.45)
        .help(item.exists ? item.videoURL.path : loc("library.missing"))
    }
}

private struct LibraryDetail: View {
    @Environment(AppState.self) private var app
    var item: LibraryItem

    /// Held in state rather than built inline: a player constructed in `body`
    /// is rebuilt on every evaluation, which restarts playback and leaks
    /// players as the view updates.
    /// Empty, and filled by `LibraryPlayer`. Built here only so it survives the
    /// view updates that come with each selection; what it holds is the
    /// player's own business.
    @State private var player = AVPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if item.exists {
                    LibraryPlayer(player: player, url: item.videoURL, itemID: item.id)
                        .aspectRatio(aspect, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 12))
                        .onDisappear { player.pause() }
                }

                GlassCard(title: loc("compose.prompt.title"), systemImage: "text.alignleft") {
                    Text(item.spec.prompt)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GlassCard(title: loc("library.settings"), systemImage: "info.circle") {
                    VStack(spacing: 8) {
                        SpecRow(label: loc("library.mode"), value: item.spec.mode.label)
                        SpecRow(label: loc("compose.resolution"), value: item.spec.format.deliverySize.description)
                        SpecRow(label: loc("compose.framerate"), value: "\(item.spec.format.frameRate.rawValue) fps")
                        SpecRow(label: loc("library.duration"),
                                value: Format.clipLength(item.spec.sampling.durationSeconds))
                        SpecRow(label: loc("sampling.steps"), value: "\(item.spec.sampling.steps)")
                        if let seed = item.seed {
                            SpecRow(label: loc("library.seed"), value: String(seed),
                                    isProminent: true, isCopyable: true)
                        }
                        SpecRow(label: loc("library.filesize"), value: Format.bytes(item.fileSizeBytes))
                        if let seconds = item.renderSeconds {
                            SpecRow(label: loc("library.renderTime"), value: Format.duration(seconds))
                        }
                    }
                }

                // One row, centred: these are peers, and stacked full-width they
                // read as a list of steps to work through rather than a choice.
                HStack(spacing: 8) {
                    Button(loc("queue.reproduce"), systemImage: "equal.square") {
                        var spec = item.spec
                        spec.sampling.seed = item.seed
                        _ = app.engine.enqueue(spec)
                        app.section = .queue
                    }
                    .prominentButtonStyle()
                    .disabled(item.seed == nil)

                    Button(loc("library.useSettings"), systemImage: "arrow.uturn.backward") {
                        app.draft = item.spec
                        app.section = .compose
                    }

                    if let audio = item.audioURL {
                        Button(loc("library.revealWav"), systemImage: "waveform") {
                            NSWorkspace.shared.activateFileViewerSelecting([audio])
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .statusBarInset()
        .background(.background.secondary)
    }

    private var aspect: CGFloat {
        let size = item.spec.format.deliverySize
        return CGFloat(size.width) / CGFloat(max(size.height, 1))
    }
}
