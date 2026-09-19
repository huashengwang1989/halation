import SwiftUI

// MARK: - Catalog sections
//
// Split from ModelsView so that file stays about the screen's structure, and this
// one is about how a single catalog entry is presented.

struct TaskSection: View {
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

struct ComponentSection: View {
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

struct EntryRow: View {
    @Environment(AppState.self) private var app
    var entry: CatalogEntry
    var isSelectable: Bool
    @State private var confirmingDelete = false
    @State private var deleteError: String?

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
                    // Which engine loads this. The two sets are not
                    // interchangeable, and several entries exist only for one.
                    TagPill(text: entry.backend.label,
                            tint: entry.backend == .comfyUI ? .purple : .blue)
                    TagPill(text: entry.provenance.label)
                    if !entry.isUsableHere {
                        TagPill(text: "Not runnable here", tint: .red)
                    }
                    if isSelected {
                        TagPill(text: "In use", tint: .accentColor)
                    }
                }

                Text(entry.repoID)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let deleteError {
                    Label(deleteError, systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
                    // Only meaningful once the file is on disk; before that the
                    // Download button is the only thing worth offering.
                    if isSelectable {
                        Button(isSelected ? "Selected" : "Use") { select() }
                            .disabled(isSelected || !entry.isUsableHere)
                            .help(selectionHelp)
                    }
                    HStack(spacing: 6) {
                        Button("Reveal", systemImage: "folder") {
                            if let url = app.modelStore.localPath(for: entry) {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        }
                        .accessibilityLabel("Reveal \(entry.repoID) in Finder")

                        Button("Delete", systemImage: "trash", role: .destructive) {
                            confirmingDelete = true
                        }
                        .disabled(!isDeletable)
                        .help(deleteHelp)
                        .accessibilityLabel("Delete \(entry.displayName)")
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                } else {
                    Button("Download") { app.downloads.enqueue([entry]) }
                        .disabled(!entry.isUsableHere)
                }
            }
            .frame(width: 92)
            .confirmationDialog("Delete \(entry.displayName)?",
                                isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Move to Trash", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Frees about \(Format.bytes(entry.approximateBytes)) from the shared "
                     + "models folder, which other projects on this Mac may also be using — "
                     + "anything relying on \(entry.repoID) would have to download it again. "
                     + "The files go to the Trash, so this can be undone until you empty it.")
            }
        }
        .padding(10)
        .background(.quaternary.opacity(isSelected ? 0.3 : 0.16), in: .rect(cornerRadius: 10))
        .opacity(entry.isUsableHere ? 1 : 0.55)
    }

    /// Deletion is blocked while anything is rendering: the files may be mapped
    /// into the running process, and a half-deleted model fails confusingly.
    private var isDeletable: Bool {
        isInstalled && !isSelected && !app.engine.isRunning
    }

    private var deleteHelp: String {
        if app.engine.isRunning { return "Not while a render is running" }
        if isSelected { return "In use for the current render — choose another first" }
        return "Move this model to the Trash"
    }

    private func delete() {
        do {
            let freed = try app.modelStore.delete(entry)
            deleteError = nil
            if freed > 0 { app.note("Moved \(Format.bytes(freed)) to the Trash.") }
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private var selectionHelp: String {
        if !entry.isUsableHere { return entry.unusableReason ?? "Not runnable on this Mac" }
        if !isInstalled { return "Download this first" }
        if isSelected { return "Already in use for the current render" }
        return "Use this for the current render"
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

struct TagPill: View {
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
struct UnrecognisedCard: View {
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
