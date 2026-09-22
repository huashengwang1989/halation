import SwiftUI

// MARK: - Sampling

struct SamplingCard: View {
    @Environment(AppState.self) private var app
    @Binding var spec: GenerationSpec
    @State private var lockSeed = false

    /// Step guidance depends on the engine: a turbo LoRA changes what a good
    /// number is by an order of magnitude.
    private var stepsFootnote: String {
        let recommended = app.recommendedSteps(for: app.draft.mode)
        let advice: String = if app.draftBackend == .comfyUI, recommended <= 6 {
            loc("sampling.steps.note.turbo", "\(recommended)")
        } else {
            loc("sampling.steps.note.undistilled", "\(recommended)")
        }
        return loc("sampling.steps.note", advice)
    }

    /// What the model will actually render, given the frame grid.
    private var snappedNote: String {
        let frames = spec.sampling.frameCount
        let seconds = spec.sampling.effectiveSeconds
        if FrameGrid.isExact(forSeconds: spec.sampling.durationSeconds) {
            return loc("sampling.snapped.exact", "\(frames)", "\(spec.sampling.durationSeconds)")
        }
        let text = seconds.formatted(.number.precision(.fractionLength(2)))
        return loc("sampling.snapped.inexact", "\(frames)", text)
    }

    var body: some View {
        GlassCard(title: loc("sampling.title"), systemImage: "dial.medium",
                  footnote: stepsFootnote) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent(loc("sampling.duration")) {
                        HStack {
                            // Both ends are labelled. The range starts at 5, so
                            // the knob sits hard left at the minimum and read as
                            // zero — as though nothing would be generated. The
                            // scale has to say what its first tick means.
                            Slider(value: .init(
                                get: { Double(spec.sampling.durationSeconds) },
                                set: { spec.sampling.durationSeconds = Int($0.rounded()) }),
                                   in: 5...15, step: 1,
                                   onEditingChanged: { editing in
                                       // On release only. A slider logged while
                                       // it moves writes a line per pixel and
                                       // buries everything else in the file.
                                       guard !editing else { return }
                                       InteractionLog.shared.record(
                                           .slide, "sampling.duration",
                                           value: "\(spec.sampling.durationSeconds)")
                                   },
                                   minimumValueLabel: Text(Format.clipLength(5)),
                                   maximumValueLabel: Text(Format.clipLength(15))) {
                                // For VoiceOver only: LabeledContent already
                                // shows this name beside the control.
                                Text(loc("sampling.duration"))
                            }
                            .labelsHidden()
                            // Whole seconds: one tick, one second. The grid-snapped
                            // result is reported underneath rather than here, so the
                            // control itself stays predictable.
                            // Formatted, not "\(seconds) s": the unit is a
                            // translated string, and the slider's own end
                            // labels already go through Format.clipLength.
                            // minWidth rather than a fixed width, because the
                            // unit is one character in English and six in Thai;
                            // the minimum is still enough that the number
                            // changing from 9 to 10 does not shift the row.
                            Text(Format.clipLength(spec.sampling.durationSeconds))
                                .monospacedDigit()
                                .frame(minWidth: 42, alignment: .trailing)
                        }
                    }
                    Text(snappedNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent(loc("sampling.steps")) {
                    HStack {
                        Slider(value: .init(
                            get: { Double(spec.sampling.steps) },
                            set: { spec.sampling.steps = Int($0.rounded()) }),
                               in: 4...60, step: 1,
                               onEditingChanged: { editing in
                                   guard !editing else { return }
                                   InteractionLog.shared.record(
                                       .slide, "sampling.steps",
                                       value: "\(spec.sampling.steps)")
                               },
                               minimumValueLabel: Text("4"),
                               maximumValueLabel: Text("60")) {
                            Text(loc("sampling.steps"))
                        }
                        .labelsHidden()
                        Text("\(spec.sampling.steps)")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }

                Divider()

                Toggle(loc("sampling.seed.fixed"), isOn: Binding(
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
                        Button(loc("sampling.seed.randomise"), systemImage: "die.face.5") {
                            spec.sampling.seed = Int64.random(in: 0..<Int64(1) << 47)
                        }
                    }
                    Text(loc("sampling.seed.note"))
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
        GlassCard(title: loc("compose.output.title"), systemImage: "film",
                  footnote: loc("compose.output.footnote")) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("compose.aspect")).font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(AspectRatio.allCases) { ratio in
                            AspectButton(ratio: ratio, isSelected: spec.format.aspectRatio == ratio) {
                                spec.format.aspectRatio = ratio
                            }
                        }
                    }
                }

                Picker(loc("compose.resolution"), selection: $spec.format.resolution) {
                    ForEach(ResolutionTier.allCases) { tier in
                        Text(tier.label).tag(tier)
                    }
                }
                Text(spec.format.resolution.detail)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker(loc("compose.framerate"), selection: $spec.format.frameRate) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.label).tag(rate)
                    }
                }
                Text(spec.format.frameRate.detail)
                    .font(.caption).foregroundStyle(.secondary)

                Picker(loc("compose.codec"), selection: $spec.format.codec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.label).tag(codec)
                    }
                }
                Text(spec.format.codec.detail)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker(loc("compose.audio"), selection: $spec.format.audio) {
                    ForEach(AudioHandling.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                Text(loc("compose.audio.footnote"))
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
        .help(loc("compose.aspect.help", ratio.label, ratio.nativeSize.description))
        // The swatch carries its meaning in shape and colour alone, so state and
        // size have to be spoken.
        .accessibilityLabel(loc("compose.aspect.accessibility", ratio.label))
        .accessibilityValue(loc("compose.aspect.pixels", "\(ratio.nativeSize.width)", "\(ratio.nativeSize.height)"))
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
    @State private var isFlashing = false

    var body: some View {
        Menu {
            ForEach(GenerationPreset.builtIns) { preset in
                Button(preset.displayName) { app.apply(preset: preset) }
            }
            if !app.library.presets.isEmpty {
                // A rule between what ships with the app and what the user made,
                // because only the second kind can be deleted.
                Divider()
                ForEach(app.library.presets) { preset in
                    Button(preset.displayName) { app.apply(preset: preset) }
                }
                Divider()
                Menu(loc("compose.preset.delete")) {
                    ForEach(app.library.presets) { preset in
                        Button(preset.displayName, role: .destructive) {
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
        .raisedButtonStyle()
        .fixedSize()
        .help(loc("compose.presets.help"))
        .overlay {
            Capsule()
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .opacity(isFlashing ? 1 : 0)
                .allowsHitTesting(false)
        }
        .onChange(of: app.presetSavedPulse) { _, _ in flash() }
    }

    /// Two quick pulses — enough to catch the eye without being a distraction.
    /// The same shape the Compose summary uses for a blocking problem.
    private func flash() {
        withAnimation(.easeOut(duration: 0.18)) { isFlashing = true }
        withAnimation(.easeIn(duration: 0.35).delay(0.9)) { isFlashing = false }
    }

    /// Shows the preset the draft currently matches, so the control reads as state
    /// rather than as a bare menu.
    private var currentPresetName: String {
        app.library.allPresets.first { $0.spec.sampling == app.draft.sampling
                                    && $0.spec.format == app.draft.format }?.displayName
            ?? loc("compose.presets")
    }
}
