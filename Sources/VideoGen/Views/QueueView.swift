import SwiftUI

struct QueueView: View {
    @Environment(AppState.self) private var app
    @State private var selection: UUID?
    @State private var showingLog = false

    var body: some View {
        @Bindable var app = app

        Group {
            if app.engine.jobs.isEmpty {
                ContentUnavailableView {
                    Label("Nothing queued", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Renders you start from Compose appear here. They keep running while you work, and survive quitting the app.")
                } actions: {
                    Button("Go to Compose") { app.section = .compose }
                        .buttonStyle(.glassProminent)
                }
            } else {
                List(selection: $selection) {
                    ForEach(app.engine.jobs) { job in
                        JobRow(job: job)
                            .tag(job.id)
                            .contextMenu { menu(for: job) }
                    }
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            // One group, so the system draws a single Finder-style segmented
            // container instead of separate glass pills butting together.
            ToolbarItemGroup {
                Toggle(isOn: Binding(get: { app.engine.autoStart },
                                     set: { app.engine.autoStart = $0 })) {
                    Label("Auto-start", systemImage: app.engine.autoStart ? "play.fill" : "pause.fill")
                }
                .help("When off, the queue finishes the current render and then stops")

                Button {
                    showingLog = true
                } label: {
                    Label("Log", systemImage: "text.alignleft")
                }
                .disabled(app.engine.currentLog.isEmpty)
                .help("Show the current render's output")
            }

            ToolbarSpacer(.fixed)

            ToolbarItem {
                Button(role: .destructive) {
                    app.engine.clearFinished()
                } label: {
                    Label("Clear Finished", systemImage: "trash")
                }
                .disabled(!app.engine.jobs.contains { $0.state.isTerminal })
            }
        }
        .sheet(isPresented: $showingLog) { LogSheet() }
    }

    @ViewBuilder
    private func menu(for job: RenderJob) -> some View {
        if job.state == .queued {
            Button("Move to Front", systemImage: "arrow.up.to.line") {
                app.engine.moveToFront(job.id)
            }
        }
        if !job.state.isTerminal {
            Button("Cancel", systemImage: "xmark", role: .destructive) {
                app.engine.cancel(job.id)
            }
        } else {
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
        if let url = job.outputURL {
            Divider()
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

private struct JobRow: View {
    var job: RenderJob

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: job.state.symbolName)
                .accessibilityHidden(true)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 24)
                .symbolEffect(.pulse, isActive: job.state.isActive)

            VStack(alignment: .leading, spacing: 5) {
                Text(job.title)
                    .lineLimit(2)
                    .font(.body)

                HStack(spacing: 6) {
                    Text(job.state.label)
                    Text("·")
                    Text("\(job.spec.sampling.durationSeconds) s")
                    Text("·")
                    Text(job.spec.format.generationSize.description)
                    Text("·")
                    Text("\(job.spec.sampling.steps) steps")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if job.state.isActive {
                    ProgressView(value: job.overallProgress)
                        .progressViewStyle(.linear)
                        .accessibilityHidden(true)   // spoken by the row's value
                    HStack(spacing: 6) {
                        if job.totalSteps > 0 {
                            Text("step \(job.completedSteps)/\(job.totalSteps)")
                        }
                        if let perStep = job.secondsPerStep {
                            Text("· \(Format.duration(perStep))/step")
                        }
                        if let remaining = job.estimatedRemaining {
                            Text("· about \(Format.duration(remaining)) left")
                        }
                        if let memory = job.peakMemoryBytes {
                            Text("· \(Format.bytes(memory)) peak")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                }

                if let message = job.failureMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                if job.state == .finished, let elapsed = job.elapsed {
                    Text("Took \(Format.duration(elapsed))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(job.title)
        .accessibilityValue(spokenState)
    }

    /// State, progress and any failure, as one sentence.
    private var spokenState: String {
        var parts = [job.state.label]
        if job.state.isActive {
            parts.append("\(Int(job.overallProgress * 100)) percent")
            if job.totalSteps > 0 {
                parts.append("step \(job.completedSteps) of \(job.totalSteps)")
            }
            if let remaining = job.estimatedRemaining {
                parts.append("about \(Format.duration(remaining)) remaining")
            }
        }
        if let message = job.failureMessage { parts.append(message) }
        if job.state == .finished, let elapsed = job.elapsed {
            parts.append("took \(Format.duration(elapsed))")
        }
        return parts.joined(separator: ", ")
    }

    private var tint: Color {
        switch job.state {
        case .finished: .green
        case .failed: .red
        case .cancelled: .secondary
        case .queued: .secondary
        default: .accentColor
        }
    }
}

private struct LogSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Render log").font(.headline)
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        app.engine.currentLog.joined(separator: "\n"), forType: .string)
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(app.engine.currentLog.enumerated()), id: \.offset) { _, line in
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
        .frame(width: 720, height: 460)
    }
}
