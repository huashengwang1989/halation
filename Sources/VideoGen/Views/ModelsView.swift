import SwiftUI

struct ModelsView: View {
    @Environment(AppState.self) private var app
    @State private var showingUnsupported = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FolderCard()

                if app.downloads.pendingCount > 0 || !app.downloads.transfers.isEmpty {
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
        GlassCard(title: "Downloads", systemImage: "arrow.down.circle") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(app.downloads.transfers) { transfer in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(transfer.entry.repoID)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
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
                                .accessibilityLabel("Cancel download of \(transfer.entry.repoID)")
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
                            HStack {
                                Text("\(Format.bytes(transfer.completedBytes)) of \(Format.bytes(transfer.totalBytes))")
                                if let file = transfer.currentFile {
                                    Text("· \(file)").lineLimit(1).truncationMode(.middle)
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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

// MARK: - Catalog sections

private struct TaskSection: View {
    @Environment(AppState.self) private var app
    var task: ModelTask
    var showingUnsupported: Bool

    var body: some View {
        GlassCard(title: task.label, systemImage: "cube.box", footnote: task.detail) {
            VStack(spacing: 10) {
                ForEach(visible) { entry in
                    EntryRow(entry: entry, isSelectable: true)
                }
            }
        }
    }

    private var visible: [CatalogEntry] {
        ModelCatalog.transformers(task: task)
            .filter { showingUnsupported || $0.isUsableHere }
    }
}

private struct ComponentSection: View {
    @Environment(AppState.self) private var app
    var role: ModelRole
    var showingUnsupported: Bool

    var body: some View {
        GlassCard(title: role.label, systemImage: "puzzlepiece.extension",
                  footnote: role.detail) {
            VStack(spacing: 10) {
                ForEach(visible) { entry in
                    EntryRow(entry: entry, isSelectable: role == .textEncoder)
                }
            }
        }
    }

    private var visible: [CatalogEntry] {
        ModelCatalog.entries(role: role).filter { showingUnsupported || $0.isUsableHere }
    }
}

private struct EntryRow: View {
    @Environment(AppState.self) private var app
    var entry: CatalogEntry
    var isSelectable: Bool

    private var isInstalled: Bool { app.modelStore.isInstalled(entry) }

    private var isSelected: Bool {
        entry.role == .transformer
            ? app.draft.transformerEntryID == entry.id
            : app.draft.textEncoderEntryID == entry.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isInstalled ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .font(.title3)
                .accessibilityLabel(isInstalled ? "Installed" : "Not installed")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.quantization.label).font(.callout.weight(.medium))
                    TagPill(text: entry.provenance.label)
                    if !entry.isUsableHere {
                        TagPill(text: "Not runnable here", tint: .red)
                    }
                    if isSelected {
                        TagPill(text: "In use", tint: .accentColor)
                    }
                }

                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let reason = entry.unusableReason {
                    Label(reason, systemImage: "nosign")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Label(Format.bytes(entry.approximateBytes), systemImage: "internaldrive")
                    if let resident = entry.approximateResidentBytes {
                        Label("\(Format.bytes(resident)) in memory", systemImage: "memorychip")
                    }
                    if let card = entry.huggingFaceURL {
                        Link("Model card", destination: card)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                if isInstalled {
                    if isSelectable {
                        Button(isSelected ? "Selected" : "Use") { select() }
                            .disabled(isSelected || !entry.isUsableHere)
                    }
                    Button("Reveal", systemImage: "folder") {
                        if let url = app.modelStore.localPath(for: entry) {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Reveal \(entry.repoID) in Finder")
                } else {
                    Button("Download") { app.downloads.enqueue([entry]) }
                        .disabled(!entry.isUsableHere)
                }
            }
            .frame(width: 92)
        }
        .padding(10)
        .background(.quaternary.opacity(isSelected ? 0.3 : 0.16), in: .rect(cornerRadius: 10))
        .opacity(entry.isUsableHere ? 1 : 0.55)
    }

    private func select() {
        if entry.role == .transformer {
            app.draft.transformerEntryID = entry.id
            // Selecting a checkpoint implies its task.
            if let task = entry.task, task != app.draft.task {
                app.draft.mode = task.supportedModes.first ?? app.draft.mode
            }
        } else {
            app.draft.textEncoderEntryID = entry.id
        }
    }
}

private struct TagPill: View {
    var text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.16), in: .capsule)
            .foregroundStyle(tint)
    }
}

/// Anything in the folder that is clearly a model but not one we drive. Shown so
/// the folder never looks emptier than it is.
private struct UnrecognisedCard: View {
    @Environment(AppState.self) private var app

    private var others: [InstalledModel] {
        app.modelStore.installed.filter { !$0.isKnown }
    }

    var body: some View {
        if !others.isEmpty {
            GlassCard(title: "Other models in this folder", systemImage: "questionmark.folder",
                      footnote: "These belong to other projects. This app leaves them alone.") {
                VStack(spacing: 6) {
                    ForEach(others) { model in
                        HStack {
                            Text(model.repoID).font(.callout).lineLimit(1)
                            TagPill(text: model.layout.label)
                            Spacer()
                            Text(Format.bytes(model.sizeBytes))
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}
