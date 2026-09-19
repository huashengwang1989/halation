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

    /// Below this the grid and the inspector cannot both be usable.
    private var isNarrow: Bool { width > 0 && width < 820 }

    var body: some View {
        Group {
            if app.library.items.isEmpty {
                ContentUnavailableView {
                    Label("No videos yet", systemImage: "film.stack")
                } description: {
                    Text("Finished renders are saved to \(app.library.outputFolder.path(percentEncoded: false)), each with a JSON file recording the exact settings that produced it.")
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
                                LibraryTile(item: item, isSelected: selection == item.id)
                                    .onTapGesture { selection = item.id }
                                    .contextMenu { menu(for: item) }
                            }
                        }
                        .padding(18)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .frame(maxWidth: .infinity)

                    // Below this there is not enough width for a grid and an
                    // inspector, so the inspector opens as a sheet instead of being
                    // squeezed into an unreadable column.
                    if !isNarrow, let selected = filtered.first(where: { $0.id == selection }) {
                        Divider()
                        LibraryDetail(item: selected)
                            .frame(width: 360)
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .searchable(text: $search, prompt: "Search prompts")
        .sheet(isPresented: Binding(
            get: { isNarrow && selection != nil },
            set: { if !$0 { selection = nil } })) {
            if let selected = filtered.first(where: { $0.id == selection }) {
                VStack(spacing: 0) {
                    HStack {
                        Text(selected.title).font(.headline).lineLimit(1)
                        Spacer()
                        Button("Done") { selection = nil }
                            .buttonStyle(.glassProminent)
                    }
                    .padding()
                    Divider()
                    LibraryDetail(item: selected)
                }
                .frame(width: 460, height: 640)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Reveal Folder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([app.library.outputFolder])
                }
                Button("Refresh", systemImage: "arrow.clockwise") { app.library.reload() }
            }
        }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if item.exists {
                    VideoPlayer(player: AVPlayer(url: item.videoURL))
                        .aspectRatio(aspect, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 12))
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
    }

    private var aspect: CGFloat {
        let size = item.spec.format.deliverySize
        return CGFloat(size.width) / CGFloat(max(size.height, 1))
    }
}
