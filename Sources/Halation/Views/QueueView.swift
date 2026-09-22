import SwiftUI

struct QueueView: View {
    @Environment(AppState.self) private var app
    @State private var selection: UUID?
    @State private var logJobID: UUID?

    var body: some View {
        Group {
            if app.engine.jobs.isEmpty {
                ContentUnavailableView {
                    Label(loc("queue.empty.title"), systemImage: "list.bullet.rectangle")
                } description: {
                    Text(loc("queue.empty.detail"))
                } actions: {
                    Button(loc("queue.goCompose")) { app.section = .compose }
                        .prominentButtonStyle()
                }
            } else {
                List(selection: $selection) {
                    ForEach(app.engine.jobs) { job in
                        JobRow(job: job, showLog: { logJobID = job.id })
                            .tag(job.id)
                            .contextMenu { menu(for: job) }
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds()
                .statusBarInset()
            }
        }
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    app.engine.clearFinished()
                } label: {
                    Label(loc("queue.clearFinished"), systemImage: "trash")
                }
                .disabled(!app.engine.jobs.contains { $0.state.isTerminal })
                .help(loc("queue.clearFinished.help"))
            }
        }
        .safeAreaInset(edge: .bottom) { runtimeNotice }
        .sheet(item: $logJobID) { id in
            LogSheet(jobID: id)
        }
    }

    /// Nothing can start without the runtime, and a queue that silently refuses to
    /// move is worse than one that explains itself.
    @ViewBuilder
    private var runtimeNotice: some View {
        if !app.runtime.phase.isReady, app.engine.jobs.contains(where: { $0.state == .queued }) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(loc("queue.runtimeWarning"))
                    .font(.callout)
                Spacer()
                Button(loc("queue.openSettings")) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
            .padding(12)
            .glassSurface(in: .rect(cornerRadius: 12))
            .padding(12)
        }
    }

    @ViewBuilder
    private func menu(for job: RenderJob) -> some View {
        if job.state == .queued {
            Button(job.isHeld ? loc("queue.release") : loc("queue.hold"), systemImage: job.isHeld ? "play" : "pause") {
                app.engine.setHeld(!job.isHeld, for: job.id)
            }
            Button(loc("queue.moveToFront"), systemImage: "arrow.up.to.line") {
                app.engine.moveToFront(job.id)
            }
        }
        if job.state.isActive {
            Button(loc("queue.stop"), systemImage: "stop.fill", role: .destructive) {
                app.engine.cancel(job.id)
            }
        }
        if job.state.isTerminal {
            Button(loc("queue.renderAgain"), systemImage: "arrow.clockwise") { app.engine.retry(job.id) }
            if job.resolvedSeed != nil {
                Button(loc("queue.reproduce"), systemImage: "equal.square") {
                    app.engine.reproduce(job.id)
                }
            }
            Button(loc("queue.editCopy"), systemImage: "pencil") {
                app.draft = job.spec
                app.section = .compose
            }
        }
        Divider()
        Button(loc("queue.showLog"), systemImage: "text.alignleft") { logJobID = job.id }
        if let url = job.outputURL {
            Button(loc("queue.revealInFinder"), systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        Divider()
        Button(loc("queue.remove"), systemImage: "trash", role: .destructive) {
            app.engine.remove(job.id)
        }
    }
}

// MARK: - Row

private struct JobRow: View {
    @Environment(AppState.self) private var app
    var job: RenderJob
    var showLog: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: job.isHeld && job.state == .queued ? "pause.circle" : job.state.symbolName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 24)
                .symbolEffect(.pulse, isActive: job.state.isActive)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                // The whole prompt, wrapped. It is the one thing that tells two
                // queued jobs apart, so it is worth the rows being uneven.
                Text(job.title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                specLine

                if job.state.isActive {
                    activeProgress
                } else if job.state == .queued {
                    Text(job.isHeld ? loc("queue.held") : queuePosition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let message = job.failureMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }

                if job.state == .finished, let elapsed = job.elapsed {
                    Text(loc("queue.took", Format.duration(elapsed)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            controls
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(job.title)
        .accessibilityValue(spokenState)
    }

    /// Mode, canvas, length and steps — the identity of the render at a glance.
    private var specLine: some View {
        HStack(spacing: 6) {
            Label(job.spec.mode.label, systemImage: job.spec.mode.symbolName)
                .labelStyle(.titleAndIcon)
            if let backend = job.backend {
                Text("·")
                Text(backend.label)
            }
            Text("·")
            Text(job.spec.format.generationSize.description)
            Text("·")
            Text(Format.frames(job.spec.sampling.frameCount))
            Text("·")
            Text(Format.steps(job.spec.sampling.steps))
            if job.spec.format.codec != .h264 {
                Text("·")
                Text(job.spec.format.codec.label)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var activeProgress: some View {
        VStack(alignment: .leading, spacing: 3) {
            // While weights load, an almost-empty determinate bar reads as frozen.
            // Show an indeterminate one until there is real progress to report.
            if job.state == .preparing, (job.stageProgress ?? 0) <= 0 {
                ProgressView()
                    .progressViewStyle(.linear)
                    .accessibilityHidden(true)
            } else {
                ProgressView(value: job.overallProgress)
                    .progressViewStyle(.linear)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 6) {
                Text(job.activityDescription)
                    .foregroundStyle(.secondary)

                if job.totalSteps > 0 {
                    Text("· " + loc("queue.step", "\(job.completedSteps)", "\(job.totalSteps)"))
                }
                // Both rates while one is in flight: the average is what the ETA
                // rests on, and the latest is what tells you whether the run is
                // holding that pace or drifting off it.
                if let recent = job.secondsPerStepRecent, job.state == .generating {
                    Text("· " + loc("queue.perStep.now", Format.duration(recent)))
                }
                if let perStep = job.secondsPerStep {
                    Text("· " + loc(job.state == .generating ? "queue.perStep.average"
                                                             : "queue.perStep",
                                    Format.duration(perStep)))
                }
                if let tokens = job.promptTokenCount, tokens > 0 {
                    Text("· " + loc("queue.tokens", tokens.formatted(
                        .number.locale(Localization.currentLocale))))
                        .help(loc("queue.tokens.help", "\(tokens)",
                                  "\(job.promptTextTokenCount ?? tokens)"))
                }
                if let memory = job.peakMemoryBytes {
                    Text("· " + loc("queue.peak", Format.memory(memory)))
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
            .lineLimit(1)

            HStack(spacing: 6) {
                Label(Format.duration(job.elapsed), systemImage: "clock")
                if let remaining = job.estimatedRemaining {
                    Text("· " + loc("queue.remaining", Format.duration(remaining)))
                } else if job.state == .preparing {
                    Text("· " + loc("queue.remainingUnknown"))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    /// Per-item controls. There is no global switch: each render is held, stopped
    /// or retried on its own, which is the decision the user is actually making.
    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 4) {
            Button(action: showLog) {
                Label(loc("queue.showLog"), systemImage: "text.alignleft")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(loc("queue.log.help"))
            .accessibilityLabel(loc("queue.showLog"))

            switch job.state {
            case .queued:
                Button {
                    app.engine.setHeld(!job.isHeld, for: job.id)
                } label: {
                    Label(job.isHeld ? loc("queue.release") : loc("queue.hold"),
                          systemImage: job.isHeld ? "play.fill" : "pause.fill")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(job.isHeld ? loc("queue.release.help") : loc("queue.hold.help"))
                .accessibilityLabel(job.isHeld ? loc("queue.release") : loc("queue.hold"))

            case .preparing, .generating, .decoding, .encoding:
                Button(role: .destructive) {
                    app.engine.cancel(job.id)
                } label: {
                    Label(loc("queue.stop"), systemImage: "stop.fill")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(loc("queue.stop.help"))
                .accessibilityLabel(loc("queue.stop"))

            case .finished, .failed, .cancelled:
                Button {
                    app.engine.retry(job.id)
                } label: {
                    Label(loc("queue.renderAgain"), systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(loc("queue.renderAgain.help"))
                .accessibilityLabel(loc("queue.renderAgain"))
            }
        }
        .imageScale(.medium)
    }

    private var queuePosition: String {
        let waiting = app.engine.jobs
            .filter { $0.state == .queued && !$0.isHeld }
            .firstIndex(where: { $0.id == job.id })
        guard let waiting else { return "Queued" }
        return waiting == 0 ? loc("queue.nextUp") : loc("queue.ahead", "\(waiting)")
    }

    private var spokenState: String {
        var parts = [job.spec.mode.label, job.activityDescription]
        if job.isHeld, job.state == .queued { parts.append(loc("queue.a11y.held")) }
        if job.state.isActive {
            parts.append(loc("a11y.percent", "\(Int(job.overallProgress * 100))"))
            if job.totalSteps > 0 {
                parts.append(loc("queue.step", "\(job.completedSteps)", "\(job.totalSteps)"))
            }
            parts.append(loc("a11y.elapsed", Format.duration(job.elapsed)))
            if let remaining = job.estimatedRemaining {
                parts.append(loc("a11y.remaining", Format.duration(remaining)))
            }
        }
        if let message = job.failureMessage { parts.append(message) }
        return parts.joined(separator: ", ")
    }

    private var tint: Color {
        switch job.state {
        case .finished: .green
        case .failed: .red
        case .cancelled, .queued: .secondary
        default: .accentColor
        }
    }
}

// MARK: - Log

/// Lets a `UUID` drive a `.sheet(item:)`.
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
