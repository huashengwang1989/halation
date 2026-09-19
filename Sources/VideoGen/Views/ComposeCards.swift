import SwiftUI

// MARK: - Sampling

struct SamplingCard: View {
    @Binding var spec: GenerationSpec
    @State private var lockSeed = false

    /// What the model will actually render, given the frame grid.
    private var snappedNote: String {
        let frames = spec.sampling.frameCount
        let seconds = spec.sampling.effectiveSeconds
        if FrameGrid.isExact(forSeconds: spec.sampling.durationSeconds) {
            return "Renders \(frames) frames — exactly \(spec.sampling.durationSeconds) s at 24 fps."
        }
        let text = seconds.formatted(.number.precision(.fractionLength(2)))
        return "Renders \(frames) frames — \(text) s at 24 fps, "
             + "the nearest length the video VAE can encode."
    }

    var body: some View {
        GlassCard(title: "Sampling", systemImage: "dial.medium",
                  footnote: "Steps dominate render time almost linearly; the port defaults to 16. The video VAE only encodes frame counts of the form 17n+5, so a requested duration is rounded up to the next one it can produce.") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Duration") {
                        HStack {
                            Slider(value: .init(
                                get: { Double(spec.sampling.durationSeconds) },
                                set: { spec.sampling.durationSeconds = Int($0.rounded()) }),
                                   in: 5...15, step: 1)
                            // Whole seconds: one tick, one second. The grid-snapped
                            // result is reported underneath rather than here, so the
                            // control itself stays predictable.
                            Text("\(spec.sampling.durationSeconds) s")
                                .monospacedDigit()
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                    Text(snappedNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Steps") {
                    HStack {
                        Slider(value: .init(
                            get: { Double(spec.sampling.steps) },
                            set: { spec.sampling.steps = Int($0.rounded()) }),
                               in: 4...60, step: 1)
                        Text("\(spec.sampling.steps)")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }

                Divider()

                Toggle("Fixed seed", isOn: Binding(
                    get: { spec.sampling.seed != nil },
                    set: { spec.sampling.seed = $0 ? (spec.sampling.seed ?? 42) : nil }))
                    .toggleStyle(.switch)

                if spec.sampling.seed != nil {
                    HStack {
                        TextField("Seed", value: Binding(
                            get: { spec.sampling.seed ?? 0 },
                            set: { spec.sampling.seed = $0 }), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                        Button("Randomise", systemImage: "die.face.5") {
                            spec.sampling.seed = Int64.random(in: 0..<Int64(1) << 47)
                        }
                    }
                    Text("A fixed seed makes a render repeatable. Change any other setting and the result changes anyway.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Format

struct FormatCard: View {
    @Environment(AppState.self) private var app
    @Binding var spec: GenerationSpec

    var body: some View {
        GlassCard(title: "Output", systemImage: "film",
                  footnote: "The model always renders 24 fps at a 768 px short edge. Anything else on this card is applied afterwards, during encoding.") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aspect ratio").font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(AspectRatio.allCases) { ratio in
                            AspectButton(ratio: ratio, isSelected: spec.format.aspectRatio == ratio) {
                                spec.format.aspectRatio = ratio
                            }
                        }
                    }
                }

                Picker("Resolution", selection: $spec.format.resolution) {
                    ForEach(ResolutionTier.allCases) { tier in
                        Text(tier.label).tag(tier)
                    }
                }
                Text(spec.format.resolution.detail)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Frame rate", selection: $spec.format.frameRate) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.label).tag(rate)
                    }
                }
                Text(spec.format.frameRate.detail)
                    .font(.caption).foregroundStyle(.secondary)

                Picker("Codec", selection: $spec.format.codec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.label).tag(codec)
                    }
                }
                Text(spec.format.codec.detail)
                    .font(.caption).foregroundStyle(.secondary)

                Picker("Audio", selection: $spec.format.audio) {
                    ForEach(AudioHandling.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                Text("H3 generates 32 kHz stereo audio in the same pass as the picture; there is no silent mode that renders faster.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AspectButton: View {
    var ratio: AspectRatio
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(lineWidth: isSelected ? 2 : 1)
                    .frame(width: swatchWidth, height: swatchHeight)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(ratio.label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .frame(width: 52, height: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("\(ratio.label) — renders at \(ratio.nativeSize.description)")
        // The swatch carries its meaning in shape and colour alone, so state and
        // size have to be spoken.
        .accessibilityLabel("\(ratio.label) aspect ratio")
        .accessibilityValue("\(ratio.nativeSize.width) by \(ratio.nativeSize.height) pixels")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // Normalise every swatch into the same 34 pt box so the row reads evenly.
    private var swatchWidth: CGFloat {
        let size = ratio.nativeSize
        return size.width >= size.height
            ? 34 : 34 * CGFloat(size.width) / CGFloat(size.height)
    }

    private var swatchHeight: CGFloat {
        let size = ratio.nativeSize
        return size.height > size.width
            ? 34 : 34 * CGFloat(size.height) / CGFloat(size.width)
    }
}

// MARK: - Preset menu

struct PresetMenu: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Menu {
            ForEach(app.library.allPresets) { preset in
                Button(preset.name) { app.apply(preset: preset) }
            }
            if !app.library.presets.isEmpty {
                Divider()
                Menu("Delete Preset") {
                    ForEach(app.library.presets) { preset in
                        Button(preset.name, role: .destructive) {
                            app.library.deletePreset(preset.id)
                        }
                    }
                }
            }
        } label: {
            Label(currentPresetName, systemImage: "square.stack")
        }
        // Without an explicit title style the toolbar collapses this to an icon and
        // renders it as a circle; we want a labelled, rounded control.
        .labelStyle(.titleAndIcon)
        .menuStyle(.button)
        .buttonStyle(.glass)
        .fixedSize()
        .help("Apply a saved combination of settings")
    }

    /// Shows the preset the draft currently matches, so the control reads as state
    /// rather than as a bare menu.
    private var currentPresetName: String {
        app.library.allPresets.first { $0.spec.sampling == app.draft.sampling
                                    && $0.spec.format == app.draft.format }?.name
            ?? "Presets"
    }
}

// MARK: - Summary

/// The summary column. Scrolls independently beside the form when there is room.
struct SummarySidebar: View {
    @Binding var showingPresetNamer: Bool
    /// Incremented by the Compose toolbar when the user asks why Generate is off.
    var problemFocusCount: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                SummaryContent(showingPresetNamer: $showingPresetNamer)
                    .padding(20)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onChange(of: problemFocusCount) { _, _ in
                withAnimation(.snappy) {
                    proxy.scrollTo(ComposeAnchor.problems, anchor: .center)
                }
            }
        }
        .background(.background.secondary)
    }
}

/// The summary's cards, laid out without assuming a container. Used both in the
/// side column and inline underneath the form when the window is narrow.
struct SummaryContent: View {
    @Environment(AppState.self) private var app
    @Binding var showingPresetNamer: Bool
    @State private var isFlashing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard(title: "This render", systemImage: "info.circle") {
                VStack(spacing: 8) {
                    SpecRow(label: "Task", value: app.draft.task.rawValue)
                    SpecRow(label: "Generates at", value: app.draft.format.generationSize.description)
                    if app.draft.format.deliverySize != app.draft.format.generationSize {
                        SpecRow(label: "Delivered at", value: app.draft.format.deliverySize.description)
                    }
                    SpecRow(label: "Length",
                            value: "\(app.draft.sampling.frameCount) frames · "
                                 + app.draft.sampling.effectiveSeconds.formatted(.number.precision(.fractionLength(2))) + " s")
                    SpecRow(label: "Steps", value: "\(app.draft.sampling.steps)")
                    SpecRow(label: "Codec", value: app.draft.format.codec.label)
                    if let bitrate = app.draft.format.estimatedBitrate() {
                        SpecRow(label: "Target bitrate", value: "\(bitrate / 1_000_000) Mb/s")
                    }
                }
            }

            GlassCard(title: "Estimated time", systemImage: "clock",
                      footnote: "Scaled from the MLX port's published M3 Ultra timings for this machine's memory bandwidth. Treat it as an order of magnitude, not a promise — the first run of a session is slower because weights have to be paged in.") {
                Text(estimate)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if !app.draftProblems.isEmpty {
                GlassCard(title: "Before you generate", systemImage: "checklist") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(app.draftProblems) { ProblemBadge(problem: $0) }
                    }
                }
                .id(ComposeAnchor.problems)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.orange, lineWidth: 2)
                        .opacity(isFlashing ? 1 : 0)
                }
                .onChange(of: app.problemFocusPulse) { _, _ in flash() }
            }

            GlassCard(title: "Models", systemImage: "cube.box") {
                VStack(spacing: 8) {
                    SpecRow(label: "Transformer", value: name(app.draft.transformerEntryID))
                    SpecRow(label: "Text encoder", value: name(app.draft.textEncoderEntryID))
                    Button("Choose in Models…") { app.section = .models }
                        .frame(maxWidth: .infinity)
                }
            }

            Button("Save as Preset…", systemImage: "square.and.arrow.down") {
                showingPresetNamer = true
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two quick pulses — enough to catch the eye without being a distraction.
    private func flash() {
        withAnimation(.easeOut(duration: 0.18)) { isFlashing = true }
        withAnimation(.easeIn(duration: 0.35).delay(0.9)) { isFlashing = false }
    }

    private var estimate: String {
        guard let id = app.draft.transformerEntryID,
              let entry = ModelCatalog.entry(id: id) else { return "Select a model" }
        let size = app.draft.format.generationSize
        let range = app.draft.sampling.estimatedDuration(
            quantization: entry.quantization,
            pixels: size.width * size.height)
        return Format.durationRange(range)
    }

    private func name(_ id: String?) -> String {
        guard let id, let entry = ModelCatalog.entry(id: id) else { return "Not selected" }
        return entry.quantization.label
    }
}
