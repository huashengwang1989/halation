import SwiftUI

struct ModelsView: View {
    @Environment(AppState.self) private var app
    @State private var showingUnsupported = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FolderCard()

                if app.downloads.hasHistory {
                    TransfersCard()
                }

                ForEach(ModelTask.allCases) { task in
                    TaskSection(task: task, showingUnsupported: showingUnsupported)
                }

                ComponentSection(role: .textEncoder, showingUnsupported: showingUnsupported)
                ComponentSection(role: .support, showingUnsupported: showingUnsupported)
                ComponentSection(role: .accelerator, showingUnsupported: showingUnsupported)

                UnrecognisedCard()
            }
            .padding(20)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $showingUnsupported) {
                    Label("Show Incompatible", systemImage: "eye.slash")
                }
                .toggleStyle(.button)
                .help("Include checkpoints in formats this Mac cannot run")

                Button("Rescan", systemImage: "arrow.clockwise") {
                    Task { await app.modelStore.scan() }
                }
                .help("Re-read the shared models folder")
            }

            ToolbarSpacer(.fixed)

            ToolbarItem {
                Button("Install Recommended", systemImage: "arrow.down.circle") {
                    app.downloads.enqueue(ModelCatalog.recommendedBundle)
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.glassProminent)
            }
        }
    }
}

// MARK: - Folder

private struct FolderCard: View {
    @Environment(AppState.self) private var app

    var body: some View {
        GlassCard(title: "Shared models folder", systemImage: "folder",
                  footnote: "Downloads go into the Hugging Face cache inside this folder. Any other project pointed at "
                            + "the same folder reuses them instead of downloading a second copy.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(app.modelStore.rootURL.path(percentEncoded: false))
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Change…") { chooseFolder() }
                    Button("Reveal", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([app.modelStore.rootURL])
                    }
                }

                HStack(spacing: 18) {
                    Stat(label: "Installed", value: Format.bytes(app.modelStore.totalInstalledBytes))
                    Stat(label: "Free space", value: Format.bytes(app.modelStore.freeBytes))
                    Stat(label: "Models found", value: "\(app.modelStore.installed.count)")
                    if app.modelStore.isScanning {
                        ProgressView().controlSize(.small)
                    }
                }

                if app.modelStore.freeBytes < ModelCatalog.recommendedBytes + 20 * 1_073_741_824 {
                    Label("The recommended set needs about "
                          + "\(Format.bytes(ModelCatalog.recommendedBytes)), plus scratch "
                          + "space while rendering.",
                          systemImage: "externaldrive.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let error = app.modelStore.lastScanError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose the folder where model weights are shared between projects"
        panel.directoryURL = app.modelStore.rootURL
        if panel.runModal() == .OK, let url = panel.url {
            app.modelStore.setRoot(url)
        }
    }
}

private struct Stat: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.callout.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        // Read as "Free space, 180 GB" rather than as two loose fragments.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

// MARK: - Transfers

private struct TransfersCard: View {
    @Environment(AppState.self) private var app

    var body: some View {
        GlassCard(title: "Downloads", systemImage: "arrow.down.circle",
                  footnote: "This list covers the current session. A finished "
                          + "download stays here until cleared; what is installed "
                          + "is shown against each model below.") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(app.downloads.transfers) { transfer in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(transfer.entry.displayName)
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(transfer.entry.scopeDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            switch transfer.state {
                            case .finished:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .accessibilityLabel("Downloaded")
                            case .failed:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .accessibilityLabel("Download failed")
                            case .cancelled:
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Cancelled")
                            default:
                                Button("Cancel", systemImage: "xmark") {
                                    app.downloads.cancel(transfer.id)
                                }
                                .buttonStyle(.plain)
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Cancel download of \(transfer.entry.displayName)")
                            }
                        }

                        if !transfer.state.isTerminal {
                            ProgressView(value: transfer.fraction)
                                .progressViewStyle(.linear)
                                .accessibilityLabel("Download progress")
                                .accessibilityValue(
                                    "\(Int(transfer.fraction * 100)) percent, "
                                    + "\(Format.bytes(transfer.completedBytes)) of "
                                    + Format.bytes(transfer.totalBytes))
                            HStack(spacing: 4) {
                                if transfer.isFinalising {
                                    ProgressView().controlSize(.small).scaleEffect(0.6)
                                }
                                Text("\(Format.bytes(transfer.completedBytes)) of "
                                     + Format.bytes(transfer.totalBytes))
                                if let note = transfer.currentFile {
                                    Text("· \(note)").lineLimit(1).truncationMode(.middle)
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(transfer.isFinalising ? .secondary : .tertiary)
                            .monospacedDigit()
                        } else if let message = transfer.message, transfer.state == .failed {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }
                }

                HStack {
                    if app.downloads.pendingCount > 0 {
                        Button("Cancel All", role: .destructive) { app.downloads.cancelAll() }
                    }
                    Button("Clear Finished") { app.downloads.clearFinished() }
                    Spacer()
                }
            }
        }
    }
}
