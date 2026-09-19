import SwiftUI
import UniformTypeIdentifiers

struct ComposeView: View {
    @Environment(AppState.self) private var app
    @State private var showingPresetNamer = false
    @State private var presetName = ""

    var body: some View {
        @Bindable var app = app

        GlassEffectContainer(spacing: 18) {
            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PromptCard(spec: $app.draft)
                        ModeCard(spec: $app.draft)
                        if app.draft.mode != .textToVideo {
                            ReferencesCard(spec: $app.draft)
                        }
                        SamplingCard(spec: $app.draft)
                        FormatCard(spec: $app.draft)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 480, idealWidth: 620)

                SummarySidebar(showingPresetNamer: $showingPresetNamer)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) { PresetMenu() }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    app.generate()
                } label: {
                    Label("Generate", systemImage: "sparkles")
                }
                .buttonStyle(.glassProminent)
                .disabled(!app.canGenerate)
                .keyboardShortcut(.return, modifiers: .command)
                .help(app.canGenerate
                      ? "Add this render to the queue"
                      : "Resolve the issues listed in the summary first")
            }
        }
        .alert("Save preset", isPresented: $showingPresetNamer) {
            TextField("Name", text: $presetName)
            Button("Cancel", role: .cancel) { presetName = "" }
            Button("Save") {
                let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { app.library.savePreset(name: name, spec: app.draft) }
                presetName = ""
            }
        } message: {
            Text("Saves the current settings as a reusable recipe. The prompt, seed and attached files are not included.")
        }
    }
}

// MARK: - Prompt

private struct PromptCard: View {
    @Binding var spec: GenerationSpec

    var body: some View {
        GlassCard(title: "Prompt", systemImage: "text.alignleft",
                  footnote: "H3 responds well to camera language — shot size, lens, movement, lighting — and to a described soundscape, since it generates audio in the same pass. There is no negative prompt: the released weights are CFG-distilled, so guidance controls would do nothing.") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $spec.prompt)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 108)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 10))

            }
        }
    }
}

// MARK: - Mode

private struct ModeCard: View {
    @Environment(AppState.self) private var app
    @Binding var spec: GenerationSpec

    var body: some View {
        GlassCard(title: "Mode", systemImage: "slider.horizontal.3",
                  footnote: spec.mode.detail + taskNote) {
            Picker("Mode", selection: $spec.mode) {
                ForEach(GenerationMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: spec.mode) { _, _ in
                pruneReferences()
                app.selectBestAvailableModels()
            }
        }
    }

    /// The two tasks are separate checkpoints, so switching mode can mean switching
    /// which multi-gigabyte file gets loaded. Say so.
    private var taskNote: String {
        spec.mode == .reference
            ? " Uses the Ref2VA checkpoint."
            : " Uses the FL2VA checkpoint."
    }

    /// Drop attachments that the new mode cannot accept, and re-slot the rest.
    private func pruneReferences() {
        switch spec.mode {
        case .textToVideo:
            spec.references = []
        case .firstFrame:
            let images = spec.references.filter { $0.kind == .image }.prefix(1)
            spec.references = images.map { var copy = $0; copy.slot = .first; return copy }
        case .firstAndLastFrame:
            var images = Array(spec.references.filter { $0.kind == .image }.prefix(2))
            for index in images.indices { images[index].slot = index == 0 ? .first : .last }
            spec.references = images
        case .reference:
            spec.references = spec.references.map { var copy = $0; copy.slot = .reference; return copy }
        }
    }
}

// MARK: - References

private struct ReferencesCard: View {
    @Binding var spec: GenerationSpec
    @State private var isTargeted = false

    var body: some View {
        GlassCard(title: title, systemImage: "paperclip", footnote: footnote) {
            VStack(alignment: .leading, spacing: 12) {
                if spec.references.isEmpty {
                    DropWell(isTargeted: isTargeted, mode: spec.mode)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)],
                              spacing: 12) {
                        ForEach(spec.references) { asset in
                            ReferenceChip(asset: asset) { remove(asset) }
                        }
                    }
                }

                HStack {
                    Button("Add Files…", systemImage: "plus") { openPanel() }
                        .buttonStyle(.glass)
                    if !spec.references.isEmpty {
                        Button("Remove All", role: .destructive) { spec.references = [] }
                            .buttonStyle(.glass)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dropDestination(for: URL.self) { urls, _ in
                add(urls)
                return true
            } isTargeted: { isTargeted = $0 }
        }
    }

    private var title: String {
        spec.mode == .reference ? "References" : "Keyframes"
    }

    private var footnote: String {
        switch spec.mode {
        case .firstFrame:
            "One image, used as the opening frame. The clip animates outward from it."
        case .firstAndLastFrame:
            "Two images. The first becomes frame one, the second the final frame, and H3 generates the motion between them."
        case .reference:
            "Up to 9 images, 3 videos and 3 audio clips, 12 files in total. References define the subject, style or voice rather than an exact frame."
        case .textToVideo:
            ""
        }
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = spec.mode == .reference
        panel.canChooseDirectories = false
        panel.allowedContentTypes = spec.mode == .reference
            ? [.image, .movie, .audio]
            : [.image]
        panel.message = spec.mode == .reference
            ? "Choose reference images, videos or audio"
            : "Choose a keyframe image"
        if panel.runModal() == .OK { add(panel.urls) }
    }

    private func add(_ urls: [URL]) {
        for url in urls {
            guard let kind = Self.kind(of: url) else { continue }
            guard spec.mode == .reference || kind == .image else { continue }

            let slot: ReferenceAsset.Slot = switch spec.mode {
            case .firstFrame: .first
            case .firstAndLastFrame:
                spec.references.contains { $0.slot == .first } ? .last : .first
            default: .reference
            }

            // Respect the per-mode and per-kind ceilings instead of silently
            // accepting files the model will reject.
            let sameKind = spec.references.count { $0.kind == kind }
            if spec.mode == .reference {
                guard sameKind < kind.limit,
                      spec.references.count < ReferenceAsset.totalFileLimit else { continue }
            } else {
                guard spec.references.count < spec.mode.maxImages else { continue }
            }

            spec.references.append(ReferenceAsset(url: url, kind: kind, slot: slot))
        }
    }

    private func remove(_ asset: ReferenceAsset) {
        spec.references.removeAll { $0.id == asset.id }
        // Keep first/last consistent after a removal.
        if spec.mode == .firstAndLastFrame {
            for index in spec.references.indices {
                spec.references[index].slot = index == 0 ? .first : .last
            }
        }
    }

    private static func kind(of url: URL) -> ReferenceAsset.Kind? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        return nil
    }
}

private struct DropWell: View {
    var isTargeted: Bool
    var mode: GenerationMode

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mode.symbolName)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("Drop files here")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(isTargeted ? AnyShapeStyle(.tint.opacity(0.12))
                               : AnyShapeStyle(.quaternary.opacity(0.3)),
                    in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(isTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}

private struct ReferenceChip: View {
    var asset: ReferenceAsset
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.4))
                if asset.kind == .image, let image = NSImage(contentsOf: asset.url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: asset.kind.symbolName)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 74)
            .clipShape(.rect(cornerRadius: 8))

            Text(asset.slot == .reference ? asset.kind.label : asset.slot.label)
                .font(.caption2.weight(.medium))
            Text(asset.url.lastPathComponent)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .background(.quaternary.opacity(0.25), in: .rect(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .help(asset.url.path)
    }
}
