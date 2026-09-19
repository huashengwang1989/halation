import AVKit
import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var app
    @State private var selection: LibraryItem.ID?
    @State private var search = ""
    @State private var width: CGFloat = 0

    private var filtered: [LibraryItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return app.library.items }
        return app.library.items.filter { $0.title.lowercased().contains(query) }
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
                    Label("No videos yet", systemImage: "film.stack")
                } description: {
                    Text("Finished renders are saved to \(app.library.outputFolder.path(percentEncoded: false)), each "
                         + "with a JSON file recording the exact settings that produced it.")
                } actions: {
                    Button("Go to Compose") { app.section = .compose }
                        .buttonStyle(.glassProminent)
                }
            } else {
                HStack(spacing: 0) {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)],
                                  spacing: 16) {
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
                            }
                        }
                        .padding(18)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .frame(maxWidth: .infinity)

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
        .searchable(text: $search, prompt: "Search prompts")
        .toolbar {
            ToolbarItemGroup {
                Button("Reveal Folder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([app.library.outputFolder])
                }
                Button("Refresh", systemImage: "arrow.clockwise") { app.library.reload() }
            }
        }
    }

    /// Spoken after the title: what this clip is, in the order it matters.
    private func accessibilityDescription(of item: LibraryItem) -> String {
        var parts = [
            "\(item.spec.sampling.durationSeconds) seconds",
            item.spec.format.deliverySize.description.replacingOccurrences(of: "×", with: " by "),
            item.spec.format.codec.label,
        ]
        if !item.exists { parts.append("file missing") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func menu(for item: LibraryItem) -> some View {
        Button("Open", systemImage: "play.rectangle") {
            NSWorkspace.shared.open(item.videoURL)
        }
        Button("Reveal in Finder", systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.videoURL])
        }
        Divider()
        Button("Use These Settings", systemImage: "arrow.uturn.backward") {
            app.draft = item.spec
            app.draft.sampling.seed = item.seed
            app.section = .compose
        }
        Button("Render Again", systemImage: "arrow.clockwise") {
            var spec = item.spec
            spec.sampling.seed = nil
            _ = app.engine.enqueue(spec)
            app.section = .queue
        }
        Divider()
        Button("Move to Trash", systemImage: "trash", role: .destructive) {
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
                Text("\(item.spec.sampling.durationSeconds)s")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .glassEffect(.regular, in: .capsule)
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
        .help(item.exists ? item.videoURL.path : "This file is no longer on disk")
    }
}

private struct LibraryDetail: View {
    @Environment(AppState.self) private var app
    var item: LibraryItem

    /// Held in state rather than built inline: `VideoPlayer(player: AVPlayer(url:))`
    /// constructs a fresh player on every body evaluation, which restarts playback
    /// and leaks players as the view updates.
    @State private var player: AVPlayer
    @State private var shownItemID: LibraryItem.ID

    init(item: LibraryItem) {
        self.item = item
        _player = State(initialValue: AVPlayer(url: item.videoURL))
        _shownItemID = State(initialValue: item.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if item.exists {
                    VideoPlayer(player: player)
                        .aspectRatio(aspect, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 12))
                        .onDisappear { player.pause() }
                }

                GlassCard(title: "Prompt", systemImage: "text.alignleft") {
                    Text(item.spec.prompt)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GlassCard(title: "Settings", systemImage: "info.circle") {
                    VStack(spacing: 8) {
                        SpecRow(label: "Mode", value: item.spec.mode.label)
                        SpecRow(label: "Resolution", value: item.spec.format.deliverySize.description)
                        SpecRow(label: "Frame rate", value: "\(item.spec.format.frameRate.rawValue) fps")
                        SpecRow(label: "Duration", value: "\(item.spec.sampling.durationSeconds) s")
                        SpecRow(label: "Steps", value: "\(item.spec.sampling.steps)")
                        if let seed = item.seed {
                            SpecRow(label: "Seed", value: String(seed), isProminent: true)
                        }
                        SpecRow(label: "File size", value: Format.bytes(item.fileSizeBytes))
                        if let seconds = item.renderSeconds {
                            SpecRow(label: "Render time", value: Format.duration(seconds))
                        }
                    }
                }

                VStack(spacing: 8) {
                    Button("Reproduce Exactly", systemImage: "equal.square") {
                        var spec = item.spec
                        spec.sampling.seed = item.seed
                        _ = app.engine.enqueue(spec)
                        app.section = .queue
                    }
                    .buttonStyle(.glassProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(item.seed == nil)

                    Button("Use These Settings", systemImage: "arrow.uturn.backward") {
                        app.draft = item.spec
                        app.section = .compose
                    }
                    .frame(maxWidth: .infinity)

                    if let audio = item.audioURL {
                        Button("Reveal WAV", systemImage: "waveform") {
                            NSWorkspace.shared.activateFileViewerSelecting([audio])
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(18)
        }
        .background(.background.secondary)
        .onChange(of: item.id) { _, newID in
            guard newID != shownItemID else { return }
            shownItemID = newID
            player.pause()
            player.replaceCurrentItem(with: AVPlayerItem(url: item.videoURL))
        }
    }

    private var aspect: CGFloat {
        let size = item.spec.format.deliverySize
        return CGFloat(size.width) / CGFloat(max(size.height, 1))
    }
}
