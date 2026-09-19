import SwiftUI

struct QueueView: View {
    @Environment(AppState.self) private var app
    @State private var selection: UUID?
    @State private var logJobID: UUID?

    var body: some View {
        Group {
            if app.engine.jobs.isEmpty {
                ContentUnavailableView {
                    Label("Nothing queued", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Renders you start from Compose appear here. They keep running "
                         + "while you work, and survive quitting the app.")
                } actions: {
                    Button("Go to Compose") { app.section = .compose }
                        .buttonStyle(.glassProminent)
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
            }
        }
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    app.engine.clearFinished()
                } label: {
                    Label("Clear Finished", systemImage: "trash")
                }
                .disabled(!app.engine.jobs.contains { $0.state.isTerminal })
                .help("Remove finished, failed and cancelled renders from this list")
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
                Text("The Python runtime is not ready, so queued renders cannot start.")
                    .font(.callout)
                Spacer()
                Button("Open Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .padding(12)
        }
    }

    @ViewBuilder
    private func menu(for job: RenderJob) -> some View {
        if job.state == .queued {
            Button(job.isHeld ? "Release" : "Hold", systemImage: job.isHeld ? "play" : "pause") {
                app.engine.setHeld(!job.isHeld, for: job.id)
            }
            Button("Move to Front", systemImage: "arrow.up.to.line") {
                app.engine.moveToFront(job.id)
            }
        }
        if job.state.isActive {
            Button("Stop", systemImage: "stop.fill", role: .destructive) {
                app.engine.cancel(job.id)
            }
        }
        if job.state.isTerminal {
            Button("Render Again", systemImage: "arrow.clockwise") { app.engine.retry(job.id) }
            if job.resolvedSeed != nil {
                Button("Reproduce Exactly", systemImage: "equal.square") {
                    app.engine.reproduce(job.id)
                }
            }
            Button("Edit a Copy", systemImage: "pencil") {
                app.draft = job.spec
                app.section = .compose
            }
        }
        Divider()
        Button("Show Log", systemImage: "text.alignleft") { logJobID = job.id }
        if let url = job.outputURL {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        Divider()
        Button("Remove from Queue", systemImage: "trash", role: .destructive) {
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
                Text(job.title)
                    .lineLimit(2)
                    .font(.body)

                specLine

                if job.state.isActive {
                    activeProgress
                } else if job.state == .queued {
                    Text(job.isHeld ? "Held — will not start until released" : queuePosition)
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
                    Text("Took \(Format.duration(elapsed))")
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
            Text("\(job.spec.sampling.frameCount) frames")
            Text("·")
            Text("\(job.spec.sampling.steps) steps")
            if job.spec.format.codec != .hevc {
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
                    Text("· step \(job.completedSteps) of \(job.totalSteps)")
                }
                if let perStep = job.secondsPerStep {
                    Text("· \(Format.duration(perStep))/step")
                }
                if let memory = job.peakMemoryBytes {
                    Text("· \(Format.bytes(memory)) peak")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
            .lineLimit(1)

            HStack(spacing: 6) {
                Label(Format.duration(job.elapsed), systemImage: "clock")
                if let remaining = job.estimatedRemaining {
                    Text("· \(Format.duration(remaining)) remaining")
                } else if job.state == .preparing {
                    Text("· remaining unknown until generation starts")
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
                Label("Log", systemImage: "text.alignleft")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Show this render's log")
            .accessibilityLabel("Show log")

            switch job.state {
            case .queued:
                Button {
                    app.engine.setHeld(!job.isHeld, for: job.id)
                } label: {
                    Label(job.isHeld ? "Release" : "Hold",
                          systemImage: job.isHeld ? "play.fill" : "pause.fill")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(job.isHeld ? "Allow this render to start" : "Hold this render back")
                .accessibilityLabel(job.isHeld ? "Release render" : "Hold render")

            case .preparing, .generating, .decoding, .encoding:
                Button(role: .destructive) {
                    app.engine.cancel(job.id)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Stop this render. Progress is lost — a render cannot be resumed.")
                .accessibilityLabel("Stop render")

            case .finished, .failed, .cancelled:
                Button {
                    app.engine.retry(job.id)
                } label: {
                    Label("Render Again", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Queue this again with a new seed")
                .accessibilityLabel("Render again")
            }
        }
        .imageScale(.medium)
    }

    private var queuePosition: String {
        let waiting = app.engine.jobs
            .filter { $0.state == .queued && !$0.isHeld }
            .firstIndex(where: { $0.id == job.id })
        guard let waiting else { return "Queued" }
        return waiting == 0 ? "Next up" : "Queued — \(waiting) ahead"
    }

    private var spokenState: String {
        var parts = [job.spec.mode.label, job.activityDescription]
        if job.isHeld, job.state == .queued { parts.append("held") }
        if job.state.isActive {
            parts.append("\(Int(job.overallProgress * 100)) percent")
            if job.totalSteps > 0 {
                parts.append("step \(job.completedSteps) of \(job.totalSteps)")
            }
            parts.append("elapsed \(Format.duration(job.elapsed))")
            if let remaining = job.estimatedRemaining {
                parts.append("about \(Format.duration(remaining)) remaining")
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

private struct LogSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var jobID: UUID

    private var lines: [String] { app.engine.log(for: jobID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Render log").font(.headline)
                    if let job = app.engine.jobs.first(where: { $0.id == jobID }) {
                        Text(job.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button("Copy All", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
                }
                .disabled(lines.isEmpty)
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if lines.isEmpty {
                ContentUnavailableView {
                    Label("No log yet", systemImage: "text.alignleft")
                } description: {
                    Text("Output appears here once this render starts. Logs are kept for "
                         + "the current session.")
                }
            } else {
                ScrollView {
                    // Selectable so any line can be copied individually.
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(12)
                }
                .defaultScrollAnchor(.bottom)
            }
        }
        .frame(width: 760, height: 480)
        .onExitCommand { dismiss() }
    }
}
