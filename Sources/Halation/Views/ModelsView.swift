import SwiftUI

struct ModelsView: View {
    @Environment(AppState.self) private var app
    @State private var showingUnsupported = false
    @State private var confirmingInstall = false

    /// The recommended set minus whatever is already on disk.
    private var pendingRecommended: [CatalogEntry] {
        ModelCatalog.recommendedBundle.filter { !app.modelStore.isInstalled($0) }
    }

    private var pendingRecommendedBytes: Int64 {
        pendingRecommended.reduce(0) { $0 + $1.approximateBytes }
    }

    /// Spells out both halves — what is coming, and what is already there — so the
    /// size is not a surprise and a partial install is obvious.
    private var installSummary: String {
        let installed = ModelCatalog.recommendedBundle.filter { app.modelStore.isInstalled($0) }
        var lines: [String] = []

        lines.append(loc("models.willDownload"))
        for entry in pendingRecommended {
            lines.append("  • \(entry.displayName) — \(Format.bytes(entry.approximateBytes))")
        }
        if !installed.isEmpty {
            lines.append("")
            lines.append(loc("models.alreadyInstalled"))
            for entry in installed {
                lines.append("  • \(entry.displayName)")
            }
        }
        lines.append("")
        lines.append(loc("models.savingTo",
            app.modelStore.rootURL.path(percentEncoded: false), Format.bytes(app.modelStore.freeBytes)))
        return lines.joined(separator: "\n")
    }

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
        .softScrollEdge(for: .top)
        .confirmationDialog(loc("models.installRecommended.title"),
                            isPresented: $confirmingInstall, titleVisibility: .visible) {
            Button(loc("models.downloadAmount", Format.bytes(pendingRecommendedBytes))) {
                app.downloads.enqueue(pendingRecommended)
            }
            Button(loc("common.cancel"), role: .cancel) {}
        } message: {
            Text(installSummary)
        }
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $showingUnsupported) {
                    Label(loc("models.showIncompatible"), systemImage: "eye.slash")
                }
                .toggleStyle(.button)
                .help(loc("models.showIncompatible.help"))

                Button(loc("models.rescan"), systemImage: "arrow.clockwise") {
                    Task { await app.modelStore.scan() }
                }
                .help(loc("models.rescan.help"))
            }

            toolbarGap()

            ToolbarItem {
                // Hidden once there is nothing left to install, rather than sitting
                // there as a button that would do nothing.
                if !pendingRecommended.isEmpty {
                    Button(loc("models.installRecommended"), systemImage: "arrow.down.circle") {
                        confirmingInstall = true
                    }
                    .labelStyle(.titleAndIcon)
                    .prominentButtonStyle()
                }
            }
        }
    }
}

// MARK: - Folder

private struct FolderCard: View {
    @Environment(AppState.self) private var app

    var body: some View {
        GlassCard(title: loc("models.folder.title"), systemImage: "folder",
                  footnote: loc("models.folder.footnote")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(app.modelStore.rootURL.path(percentEncoded: false))
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Button(loc("models.change")) { chooseFolder() }
                    Button(loc("common.reveal"), systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([app.modelStore.rootURL])
                    }
                }

                HStack(spacing: 18) {
                    Stat(label: loc("models.installed"), value: Format.bytes(app.modelStore.totalInstalledBytes))
                    Stat(label: loc("models.freeSpace"), value: Format.bytes(app.modelStore.freeBytes))
                    Stat(label: loc("models.found"), value: "\(app.modelStore.installed.count)")
                    if app.modelStore.isScanning {
                        ProgressView().controlSize(.small)
                    }
                }

                if app.modelStore.freeBytes < ModelCatalog.recommendedBytes + 20 * 1_073_741_824 {
                    Label(loc("models.spaceWarning", Format.bytes(ModelCatalog.recommendedBytes)),
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
        panel.message = loc("models.chooseFolder.message")
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
        GlassCard(title: loc("models.downloads"), systemImage: "arrow.down.circle",
                  footnote: loc("models.downloads.footnote")) {
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
                                    .accessibilityLabel(loc("models.downloaded"))
                            case .failed:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .accessibilityLabel(loc("models.downloadFailed"))
                            case .cancelled:
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(loc("state.cancelled"))
                            default:
                                Button(loc("common.cancel"), systemImage: "xmark") {
                                    app.downloads.cancel(transfer.id)
                                }
                                .buttonStyle(.plain)
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(loc("models.cancelDownload", transfer.entry.displayName))
                            }
                        }

                        if !transfer.state.isTerminal {
                            // Nothing has arrived yet: a transfer spends its first
                            // half-minute negotiating before it writes a byte, and
                            // an empty determinate bar for that long reads as
                            // stuck. Same treatment the queue gives a model load.
                            if transfer.completedBytes == 0 {
                                ProgressView()
                                    .progressViewStyle(.linear)
                                    .accessibilityLabel(loc("models.progress"))
                                    .accessibilityValue(loc("models.download.starting"))
                            } else {
                                ProgressView(value: transfer.fraction)
                                    .progressViewStyle(.linear)
                                    .accessibilityLabel(loc("models.progress"))
                                    .accessibilityValue(
                                        loc("a11y.percent", "\(Int(transfer.fraction * 100))")
                                        + ", "
                                        + loc("format.ofTotal",
                                              Format.bytes(transfer.completedBytes),
                                              Format.bytes(transfer.totalBytes)))
                            }
                            HStack(spacing: 4) {
                                if transfer.isFinalising {
                                    ProgressView().controlSize(.small).scaleEffect(0.6)
                                }
                                if transfer.completedBytes == 0 {
                                    Text(loc("models.download.starting"))
                                } else {
                                    Text(loc("format.ofTotal",
                                             Format.bytes(transfer.completedBytes),
                                             Format.bytes(transfer.totalBytes)))
                                    if let note = transfer.currentFile {
                                        Text("· \(note)").lineLimit(1).truncationMode(.middle)
                                    }
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
                        Button(loc("models.cancelAll"), role: .destructive) { app.downloads.cancelAll() }
                    }
                    Button(loc("models.clearFinished")) { app.downloads.clearFinished() }
                    Spacer()
                }
            }
        }
    }
}
