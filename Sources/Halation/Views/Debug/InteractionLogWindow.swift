import SwiftUI

/// Debug ▸ Logs. English only, like the rest of the debug menu.
///
/// The interaction trail, newest first, as the NDJSON that is actually on disk
/// rather than a prettied rendering of it. Deliberate: what is on screen should
/// be what a pipeline would receive, so a line can be copied out of here into a
/// query and behave the same.
struct InteractionLogWindow: View {
    @State private var lines: [String] = []
    @State private var search = ""
    @State private var confirmingClear = false

    private var log: InteractionLog { .shared }

    private var filtered: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return lines }
        return lines.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()
            if filtered.isEmpty {
                empty
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(minWidth: 860, minHeight: 520)
        .task { reload() }
    }

    // MARK: - Pieces

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Filter — matches the raw line, so \"kind\":\"nav\" works",
                      text: $search)
                .textFieldStyle(.plain)

            Spacer()

            Button("Reload", systemImage: "arrow.clockwise") { reload() }
            Button("Copy All", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(filtered.joined(separator: "\n"), forType: .string)
            }
            .disabled(filtered.isEmpty)
            Button("Reveal", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([InteractionLog.fileURL])
            }
            Button("Clear", systemImage: "trash", role: .destructive) {
                confirmingClear = true
            }
            .disabled(lines.isEmpty)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .confirmationDialog("Delete the interaction log?",
                            isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                log.clear()
                reload()
            }
        } message: {
            Text("Removes every recorded event, on disk and in memory. "
                 + "Nothing else is touched.")
        }
    }

    /// Monospaced and unwrapped: these are single-line records, and letting them
    /// wrap would make one event look like several.
    private var list: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(filtered.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(12)
        }
        // A ScrollView centres content shorter than its viewport, which left a
        // handful of events floating in the middle of an empty window. A frame
        // with an alignment does not fix it — inside a scroll view the proposed
        // height is unbounded, so `maxHeight: .infinity` resolves to the
        // content's own height and aligns nothing. This is the API for it.
        .defaultScrollAnchor(.topLeading)
    }

    private var empty: some View {
        VStack {
            Spacer()
            Text(lines.isEmpty ? "Nothing recorded yet." : "No line matches “\(search)”.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("\(filtered.count) of \(lines.count) events · newest first")
                .monospacedDigit()
            Spacer()
            Text(InteractionLog.fileURL.path(percentEncoded: false))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 30)
    }

    // MARK: - Data

    /// Reads the file rather than the in-memory tail, so the window shows
    /// earlier sessions too — which is the whole point of persisting it.
    /// Pending events are flushed first or the last few clicks would be missing
    /// from a window opened to look for exactly those.
    private func reload() {
        log.flush()
        lines = InteractionLog.persistedLines().reversed()
    }
}
