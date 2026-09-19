import SwiftUI
import UniformTypeIdentifiers

/// Anchor for the "Before you generate" card, so the disabled Generate button can
/// point straight at the reason.
enum ComposeAnchor {
    static let problems = "compose.problems"
}

struct ComposeView: View {
    @Environment(AppState.self) private var app
    @State private var showingPresetNamer = false
    @State private var presetName = ""
    /// Bumped when the user asks why Generate is disabled; the summary scrolls to
    /// the problems card and flashes it.
    @State private var problemFocusCount = 0
    @State private var width: CGFloat = 0

    var body: some View {
        @Bindable var app = app

        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .toolbar {
            // Presets sit with the other actions rather than in the centre slot, so
            // the leading edge belongs to the sidebar toggle and the window title.
            ToolbarItem(placement: .primaryAction) {
                PresetMenu()
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                if !app.canGenerate {
                    Button {
                        problemFocusCount += 1
                        app.highlightProblems()
                    } label: {
                        Label("Why is this disabled?", systemImage: "exclamationmark.triangle.fill")
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.orange)
                    .help(blockingSummary)
                    .accessibilityLabel("Why Generate is unavailable")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    app.generate()
                } label: {
                    Label("Generate", systemImage: "sparkles")
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.glassProminent)
                .disabled(!app.canGenerate)
                .keyboardShortcut(.return, modifiers: .command)
                .help(app.canGenerate
                      ? "Add this render to the queue"
                      : blockingSummary)
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

    // MARK: - Layout

    /// The form and the summary always sit side by side. The summary has a floor it
    /// will not go below; the form takes whatever is left. Nothing is ever hidden or
    /// reflowed underneath — only the sidebar is negotiable, and that is the split
    /// view's business, not ours.
    private var content: some View {
        HStack(spacing: 0) {
            // Allowed to go narrower than its content: `formColumn` pans instead
            // of clipping, so this floor is only about keeping the panel visible.
            formColumn
                .frame(minWidth: 220, maxWidth: .infinity)

            Divider()

            SummarySidebar(showingPresetNamer: $showingPresetNamer,
                           problemFocusCount: problemFocusCount)
                .frame(width: summaryWidth)
        }
    }

    /// The summary gives up width before the form does, down to a readable floor.
    /// 280 (form) + 250 (summary) fits the 560pt detail the window minimum
    /// guarantees, so neither column can be clipped at any window size.
    private var summaryWidth: CGFloat {
        guard width > 0 else { return 300 }
        return min(340, max(250, width * 0.32))
    }

    /// The form fills the space it is given, and pans horizontally only when that
    /// space drops below what its controls need.
    ///
    /// The content width is pinned explicitly rather than left to `minWidth`. A
    /// horizontally-scrollable `ScrollView` proposes an unbounded width to its
    /// content, which stops `Text` wrapping — every footnote would lay out on one
    /// line and drag the panel far wider than the window. Pinning the width to the
    /// viewport restores normal wrapping, and only when the viewport is narrower
    /// than `formContentMinWidth` does the content stay wider and scroll.
    private var formColumn: some View {
        GeometryReader { proxy in
            let available = proxy.size.width
            ScrollView([.vertical, .horizontal]) {
                formCards
                    .padding(20)
                    .frame(width: max(available, formContentMinWidth), alignment: .leading)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    /// The width the form's controls need to stay usable. Below this, sliders and
    /// segmented pickers degrade badly, so the panel scrolls instead of squeezing.
    private let formContentMinWidth: CGFloat = 380

    @ViewBuilder
    private var formCards: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 18) {
            PromptCard(spec: $app.draft)
            ModeCard(spec: $app.draft)
            if app.draft.mode != .textToVideo {
                ReferencesCard(spec: $app.draft)
            }
            SamplingCard(spec: $app.draft)
            FormatCard(spec: $app.draft)
        }
    }

    /// The first blocking reason, for the button's tooltip.
    private var blockingSummary: String {
        if !app.runtime.phase.isReady {
            return "The Python runtime is not ready. Open Settings › Runtime."
        }
        if let first = app.draftProblems.first(where: { $0.severity == .blocking }) {
            return first.message
        }
        return "Resolve the issues listed under “Before you generate”."
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
                    .tabMovesFocus()
                    .accessibilityLabel("Prompt")
                    .accessibilityHint("Describe the shot. Press Tab to move on, Option-Tab to insert a tab.")
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
                    if !spec.references.isEmpty {
                        Button("Remove All", role: .destructive) { spec.references = [] }
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
                .accessibilityHidden(true)
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
                        .accessibilityHidden(true)
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
            .accessibilityLabel("Remove \(asset.url.lastPathComponent)")
        }
        .help(asset.url.path)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(asset.slot == .reference ? asset.kind.label : asset.slot.label): \(asset.url.lastPathComponent)")
    }
}
