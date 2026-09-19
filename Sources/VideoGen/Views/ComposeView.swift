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
            Text("Saves the current settings as a reusable recipe. The prompt, seed and attached files are not "
                 + "included.")
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
                  footnote: "H3 responds well to camera language — shot size, lens, movement, "
                            + "lighting — and to a described soundscape, since it generates audio "
                            + "in the same pass. There is no negative prompt: the released weights "
                            + "are CFG-distilled, so guidance controls would do nothing.") {
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
