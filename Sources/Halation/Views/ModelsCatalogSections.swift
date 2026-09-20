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

    /// A transfer for this entry that has not finished, failed or been
    /// cancelled. A failed one is deliberately not counted: the button has to go
    /// back to offering a retry.
    private var activeTransfer: DownloadManager.Transfer? {
        app.downloads.transfers.first { $0.entry.id == entry.id && !$0.state.isTerminal }
    }

    /// Whether the render currently being composed would load this file.
    ///
    /// Only the transformer and the text encoder are chosen by hand. VAEs and
    /// LoRAs are not offered as a choice at all — they are loaded whenever they
    /// match the engine and the task — so "in use" has to mean the same thing for
    /// them, or their rows could never say anything but "downloaded".
    private var isInUse: Bool {
        switch entry.role {
        case .transformer, .textEncoder:
            return isSelected
        case .accelerator:
            // Used when present, skipped when not.
            return entry.backend == app.draftBackend
                && (entry.task == nil || entry.task == app.draft.task)
        case .support:
            return entry.backend == app.draftBackend && isRequired
        }
    }

    /// Whether the render would fail without this file.
    ///
    /// Deliberately not the same question as `isInUse`. A turbo LoRA is used when
    /// it is there and skipped when it is not, so its absence is nothing to warn
    /// about — which is what the warning on an undownloaded LoRA was getting
    /// wrong.
    ///
    /// For ComfyUI it asks `ComfyUIModelSet`, which is the list the engine itself
    /// checks before it will run. Reimplementing that rule here got it wrong twice
    /// over: the turbo LoRA is not on it, and the audio VAE is, for *both* tasks,
    /// even though the catalogue tags it Ref2VA.
    private var isRequired: Bool {
        guard entry.backend == app.draftBackend else { return false }
        if let file = entry.comfyUIFile {
            return ComfyUIModelSet.required(for: app.draft.task)
                .contains { $0.file == file.filename }
        }
        switch entry.role {
        case .support:                    return true
        case .transformer, .textEncoder:  return isSelected
        case .accelerator:                return false
        }
    }

    /// Required, and not on disk.
    ///
    /// Goes through `missing(in:for:)` for ComfyUI rather than `!isInstalled`, so
    /// that a user running an alternate text encoder is not told the stock one is
    /// missing — the engine accepts either, and the row should say the same.
    private var isMissingRequirement: Bool {
        guard isRequired else { return false }
        guard let file = entry.comfyUIFile else { return !isInstalled }
        return ComfyUIModelSet.missing(in: app.modelStore.rootURL, for: app.draft.task)
            .contains(file.filename)
    }

    /// Downloaded and wanted are separate questions, and the interesting cases are
    /// the ones where they disagree.
    enum Status {
        /// Not downloaded, and this render does not need it.
        case absent
        /// On disk, but not part of this render.
        case downloaded
        case inUse
        /// This render needs it and it is not there — the one state worth alarm.
        case missing
    }

    var status: Status {
        if isMissingRequirement { return .missing }
        if !isInstalled { return .absent }
        return isInUse ? .inUse : .downloaded
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusTint)
                .font(.title3)
                .accessibilityLabel(statusLabel)
                .help(statusLabel)

            ModelCard(entry: entry, isInUse: isSelected) {
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

                if let note = memoryNote {
                    Label(note, systemImage: "memorychip.fill")
                        .font(.caption)
                        .foregroundStyle(memoryFit == .tooLarge ? .orange : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                if isInstalled {
                    // Only meaningful once the file is on disk; before that the
                    // Download button is the only thing worth offering.
                    if isSelectable {
                        Button(isSelected ? loc("models.selected") : loc("models.use")) { select() }
                            .prominentButtonStyle()
                            .disabled(isSelected || !entry.isUsableHere)
                            .help(selectionHelp)
                    }
                    HStack(spacing: 6) {
                        Button(loc("common.reveal"), systemImage: "folder") {
                            if let url = app.modelStore.localPath(for: entry) {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        }
                        .accessibilityLabel(loc("models.revealInFinder", entry.repoID))

                        Button(loc("common.delete"), systemImage: "trash", role: .destructive) {
                            confirmingDelete = true
                        }
                        .disabled(!isDeletable)
                        .help(deleteHelp)
                        .accessibilityLabel(loc("common.delete") + " " + entry.displayName)
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                } else if activeTransfer != nil {
                    // Already on its way. A live Download button here invites a
                    // second press that does nothing, and says nothing about the
                    // transfer the Downloads section is already showing.
                    Button(loc("models.downloading")) {}
                        .disabled(true)
                } else {
                    Button(loc("common.download")) { app.downloads.enqueue([entry]) }
                        .disabled(!entry.isUsableHere)
                }
            }
            .frame(width: 92)
            .confirmationDialog(loc("models.delete.title", entry.displayName),
                                isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button(loc("library.moveToTrash"), role: .destructive) { delete() }
                Button(loc("common.cancel"), role: .cancel) {}
            } message: {
                Text(loc("models.delete.message", Format.bytes(entry.approximateBytes), entry.repoID))
            }
        }
        .padding(10)
        .background(.quaternary.opacity(isSelected ? 0.3 : 0.16), in: .rect(cornerRadius: 10))
        .opacity(entry.isUsableHere ? 1 : 0.55)
    }

    /// Deletion is blocked while anything is rendering: the files may be mapped
    /// into the running process, and a half-deleted model fails confusingly.
    /// Whether this checkpoint fits in what this Mac can give a model.
    private var memoryFit: MachineProfile.Fit? {
        entry.approximateResidentBytes.map(MachineProfile.fit(residentBytes:))
    }

    /// Said only when it is worth saying. A checkpoint that fits comfortably needs
    /// no remark; the size is already on the row for anyone who wants it.
    private var memoryNote: String? {
        guard let resident = entry.approximateResidentBytes, let fit = memoryFit else { return nil }
        let budget = Format.bytes(MachineProfile.usableWeightBytes)
        switch fit {
        case .comfortable: return nil
        case .tight:       return loc("models.memory.tight", Format.bytes(resident), budget)
        case .tooLarge:    return loc("models.memory.tooLarge", Format.bytes(resident), budget)
        }
    }

    private var isDeletable: Bool {
        isInstalled && !isSelected && !app.engine.isRunning
    }

    private var deleteHelp: String {
        if app.engine.isRunning { return loc("models.delete.help.running") }
        if isSelected { return loc("models.delete.help.inUse") }
        return loc("models.delete.help.ok")
    }

    private func delete() {
        do {
            let freed = try app.modelStore.delete(entry)
            deleteError = nil
            if freed > 0 { app.note(loc("models.delete.freed", Format.bytes(freed))) }
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private var selectionHelp: String {
        if !entry.isUsableHere { return entry.unusableReason ?? loc("models.notRunnable") }
        if !isInstalled { return loc("models.use.help.download") }
        if isSelected { return loc("models.use.help.inUse") }
        return loc("models.use.help.select")
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
