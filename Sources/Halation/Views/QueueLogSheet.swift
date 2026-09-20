import SwiftUI

// The per-job log window, split out of `QueueView.swift` so that file stays about
// the queue itself.

struct LogSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var jobID: UUID

    private var lines: [String] { app.engine.log(for: jobID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(loc("queue.log.title")).font(.headline)
                    if let job = app.engine.jobs.first(where: { $0.id == jobID }) {
                        Text(job.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                Spacer()
                Button(loc("queue.log.copyAll"), systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
                }
                .disabled(lines.isEmpty)
                Button(loc("common.done")) { dismiss() }
                    .prominentButtonStyle()
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if lines.isEmpty {
                // Given the whole remaining sheet, so it sits in the middle of it
                // rather than against the divider with the height below unused.
                ContentUnavailableView {
                    Label(loc("queue.log.empty.title"), systemImage: "text.alignleft")
                } description: {
                    Text(loc("queue.log.empty.detail"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
