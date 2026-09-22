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
            toolbarGap(.primaryAction)
            ToolbarItem(placement: .primaryAction) {
                if !app.canGenerate {
                    Button {
                        problemFocusCount += 1
                        app.highlightProblems()
                    } label: {
                        Label(loc("compose.generate.why"), systemImage: "exclamationmark.triangle.fill")
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.orange)
                    .help(blockingSummary)
                    .accessibilityLabel(loc("compose.generate.why"))
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    app.generate()
                } label: {
                    Label(loc("compose.generate"), systemImage: "sparkles")
                }
                .labelStyle(.titleAndIcon)
                .prominentButtonStyle()
                .disabled(!app.canGenerate)
                .keyboardShortcut(.return, modifiers: .command)
                .help(app.canGenerate ? loc("compose.generate.help.ready") : blockingSummary)
            }
        }
        // A sheet rather than an alert: an alert's message is fixed when it is
        // presented, so the objection to a duplicate name could never appear, and
        // a Save button that is merely dim does not say why.
        .sheet(isPresented: $showingPresetNamer) {
            PresetNamer(name: $presetName, taken: app.library.allPresets.map(\.displayName)) { name in
                app.library.savePreset(name: name, spec: app.draft)
                // Say where it went, and light up the control it went into.
                app.note(loc("compose.preset.saved", name))
                app.highlightPresets()
            }
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
            .softScrollEdge(for: .top)
            .statusBarInset()
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
            return loc("compose.generate.blocked.runtime")
        }
        if let first = app.draftProblems.first(where: { $0.severity == .blocking }) {
            return first.message
        }
        return loc("compose.generate.blocked.generic")
    }
}

// MARK: - Prompt

private struct PromptCard: View {
    @Binding var spec: GenerationSpec
    @FocusState private var isFocused: Bool

    var body: some View {
        GlassCard(title: loc("compose.prompt.title"), systemImage: "text.alignleft",
                  footnote: loc("compose.prompt.footnote")) {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $spec.prompt)
                    .font(.body)
                    .focused($isFocused)
                    // Writing Tools stay on, deliberately. macOS 27 puts its
                    // "write with Siri" button in a window of its own as soon as a
                    // text view appears — not when one is focused — and never takes
                    // it down, so it can float over the Queue or the Library.
                    // `.writingToolsBehavior(.disabled)` here is the only thing
                    // that removes it, and losing Writing Tools on the prompt is
                    // the worse trade. Left as a system bug to wait out.
                    .tabMovesFocus()
                    .accessibilityLabel(loc("compose.prompt.title"))
                    .accessibilityHint(loc("compose.prompt.hint"))
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
        GlassCard(title: loc("compose.mode.title"), systemImage: "slider.horizontal.3",
                  footnote: spec.mode.detail + taskNote) {
            VStack(alignment: .leading, spacing: 12) {
            SegmentedPicker(selection: $spec.mode, options: GenerationMode.allCases) { mode in
                Text(mode.label)
            }
            .accessibilityLabel(loc("compose.mode.title"))
            .onChange(of: spec.mode) { previous, mode in
                pruneReferences()
                app.selectBestAvailableModels()
                adjustSteps(from: previous, to: mode)
                // Reference mode has only one engine; drop any stale override.
                if mode == .reference { spec.backend = nil }
            }

            if spec.mode != .reference {
                Divider()
                enginePicker
            }
            }
        }
    }

    /// Engine choice, for the modes both backends implement.
    ///
    /// Reference mode is absent deliberately: only ComfyUI implements it, so a
    /// picker there would be a control with one option.
    @ViewBuilder
    private var enginePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The label sits outside the control. Inside, it picked up the track's
            // own background and looked like a fifth, permanently-off segment.
            HStack(spacing: 10) {
                Text(loc("compose.engine.label"))
                SegmentedPicker(selection: Binding(
                    get: { spec.backend ?? .mlx },
                    set: { spec.backend = $0 == .mlx ? nil : $0 }),
                                options: BackendID.allCases) { backend in
                    Text(backend.label)
                }
                .accessibilityLabel(loc("compose.engine.label"))
            }
            // The two engines read different formats, so the checkpoint has to be
            // re-picked here as well as on a mode change — otherwise switching
            // engine leaves weights selected that the new one cannot load.
            .onChange(of: spec.backend) { _, _ in app.selectBestAvailableModels() }

            Text(engineNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var engineNote: String {
        switch spec.backend ?? .mlx {
        case .mlx: loc("compose.engine.mlx.note")
        case .comfyUI: loc("compose.engine.comfy.note")
        }
    }

    /// The two tasks are separate checkpoints, so switching mode can mean switching
    /// which multi-gigabyte file gets loaded. Say so.
    private var taskNote: String {
        spec.mode == .reference
            ? loc("compose.mode.task.ref2va")
            : loc("compose.mode.task.fl2va")
    }

    /// Move the step count to something sensible for the engine that will run.
    ///
    /// A turbo LoRA is a 4-step distillation, so 4 is right there and 16 would be
    /// wasted time; undistilled weights want 16 or more, where 4 is off
    /// distribution and looks it.
    private func adjustSteps(from previous: GenerationMode, to mode: GenerationMode) {
        guard (previous == .reference) != (mode == .reference) else { return }
        spec.sampling.steps = app.recommendedSteps(for: mode)
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
