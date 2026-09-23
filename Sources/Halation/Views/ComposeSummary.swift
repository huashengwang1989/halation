import SwiftUI

// The summary column beside the Compose form: what this render will be, how long
// it should take, what is stopping it, and which weights it will load.
//
// Split from `ComposeCards.swift`, which holds the controls the user operates.
// This side only reports.

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
            .softScrollEdge(for: .top)
            .statusBarInset()
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
    @State private var showingLicence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard(title: loc("summary.render"), systemImage: "info.circle") {
                VStack(spacing: 8) {
                    SpecRow(label: loc("summary.task"), value: app.draft.task.rawValue)
                    SpecRow(label: loc("compose.engine.label"), value: app.draftBackend.label)
                    SpecRow(label: loc("summary.generates"), value: app.draft.format.generationSize.description)
                    if app.draft.format.deliverySize != app.draft.format.generationSize {
                        SpecRow(label: loc("summary.delivers"), value: app.draft.format.deliverySize.description)
                    }
                    SpecRow(label: loc("summary.length"),
                            value: renderedLength)
                    SpecRow(label: loc("sampling.steps"), value: "\(app.draft.sampling.steps)")
                    // Only when on. It changes what comes out, so it belongs in
                    // the description of the render rather than only in the
                    // control that set it — but a row reading "Off" on every
                    // render would be a line of noise.
                    if app.draftBackend == .comfyUI, app.draft.sampling.stepCache != .off {
                        SpecRow(label: loc("sampling.cache"),
                                value: app.draft.sampling.stepCache.label)
                    }
                    SpecRow(label: loc("compose.codec"), value: app.draft.format.codec.label)
                    if let bitrate = app.draft.format.estimatedBitrate() {
                        SpecRow(label: loc("summary.bitrate"), value: "\(bitrate / 1_000_000) Mb/s")
                    }
                }
            }

            GlassCard(title: loc("summary.eta"), systemImage: "clock",
                      footnote: estimateSource) {
                Text(estimate)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if !app.draftProblems.isEmpty {
                GlassCard(title: loc("summary.problems"), systemImage: "checklist") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(app.draftProblems) { ProblemBadge(problem: $0) }

                        // The licence is the one blocking problem with a fix
                        // that is not on this screen, so it gets the way there.
                        // Everything else here is answered by changing a
                        // setting the person is already looking at.
                        if app.licenceProblem != nil {
                            Button(loc("summary.reviewLicence"),
                                   systemImage: "checkmark.shield") {
                                showingLicence = true
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 2)
                        }
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

            if let reason = app.engine.unavailableReason(for: app.draft) {
                GlassCard(title: loc("summary.engineNotReady"), systemImage: "exclamationmark.triangle") {
                    CodeSpanText(reason)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GlassCard(title: loc("summary.models"), systemImage: "cube.box") {
                VStack(alignment: .leading, spacing: 12) {
                    SelectedModel(role: loc("summary.transformer"),
                                  entryID: app.draft.transformerEntryID)
                    SelectedModel(role: loc("summary.textEncoder"),
                                  entryID: app.draft.textEncoderEntryID)
                    Button(loc("summary.chooseInModels")) { app.section = .models }
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(loc("compose.preset.save"), systemImage: "square.and.arrow.down") {
                showingPresetNamer = true
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The agreement on its own, not the whole welcome dialog: reopening
        // that would walk someone back through model installation they have
        // already done, to reach the one page they need.
        .sheet(isPresented: $showingLicence) {
            LicenceSheet()
                .environment(app)
        }
    }

    /// Two quick pulses — enough to catch the eye without being a distraction.
    private func flash() {
        withAnimation(.easeOut(duration: 0.18)) { isFlashing = true }
        withAnimation(.easeIn(duration: 0.35).delay(0.9)) { isFlashing = false }
    }

    /// "362 frames · 15.08 s" — what the model will actually produce.
    private var renderedLength: String {
        Format.framesAndLength(app.draft.sampling.frameCount,
                               seconds: app.draft.sampling.effectiveSeconds)
    }

    private var estimate: String {
        guard let id = app.draft.transformerEntryID,
              let entry = ModelCatalog.entry(id: id) else { return loc("summary.eta.noModel") }
        let range = app.draft.sampling.estimatedDuration(
            quantization: entry.quantization,
            pixels: app.draft.format.generationSize.pixelCount,
            secondsPerStepMegapixel: measuredThroughput ?? RenderThroughput.predicted)
        return Format.durationRange(range)
    }

    /// What renders on this Mac have actually cost, if any have.
    private var measuredThroughput: Double? {
        RenderThroughput.measured(from: app.library.items, backend: app.draftBackend)
    }

    /// Says where the estimate comes from, because the two are worth very
    /// different amounts: a measurement from this Mac, or an extrapolation from a
    /// published figure for a different one.
    private var estimateSource: String {
        let samples = app.library.items.filter {
            $0.renderSeconds != nil && $0.spec.resolvedBackend == app.draftBackend
        }.count
        return measuredThroughput == nil
            ? loc("summary.eta.footnote.predicted", MachineProfile.chipName)
            : loc("summary.eta.footnote.measured", "\(samples)")
    }

}

/// One of the two checkpoints a render loads, described exactly as the Models
/// page describes it.
///
/// The same `ModelCard`, minus the blurb — the summary column is narrow and the
/// identity is what matters here, not the explanation.
private struct SelectedModel: View {
    let role: String
    let entryID: String?

    private var entry: CatalogEntry? { entryID.flatMap(ModelCatalog.entry(id:)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(role)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let entry {
                ModelCard(entry: entry, showsDescription: false)
            } else {
                Text(loc("summary.notSelected"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
