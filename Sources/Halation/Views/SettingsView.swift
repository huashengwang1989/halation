import SwiftUI

struct SettingsView: View {
    /// Held so the ring suppressor below re-runs whenever the tab bar rebuilds.
    @State private var tab = SettingsTab.general

    var body: some View {
        TabView(selection: $tab) {
            Tab(loc("settings.general"), systemImage: "gearshape", value: SettingsTab.general) {
                GeneralSettings()
            }
            Tab(loc("settings.runtime"), systemImage: "terminal", value: SettingsTab.runtime) {
                RuntimeSettings()
            }
            Tab("ComfyUI", systemImage: "square.stack.3d.up", value: SettingsTab.comfyUI) {
                ComfyUISettings()
            }
            Tab(loc("settings.requirements"), systemImage: "memorychip",
                value: SettingsTab.requirements) {
                RequirementsSettings()
            }
            Tab(loc("settings.cache"), systemImage: "trash", value: SettingsTab.cache) {
                CacheSettings()
            }
            Tab(loc("settings.advanced"), systemImage: "wrench.and.screwdriver", value: SettingsTab.advanced) {
                AdvancedSettings()
            }
        }
        .frame(width: 620, height: 460)
        .background(TabBarFocusRingSuppressor(trigger: tab))
    }
}

enum SettingsTab: Hashable { case general, runtime, comfyUI, requirements, cache, advanced }

/// Stops AppKit drawing a focus ring on the Settings tab bar.
///
/// The ring reads as noise wherever it lands: on an unselected tab it looks like
/// a second selection, and on the selected one it doubles up with the blue tint
/// the selection already carries.
///
/// It has to be done here because the tabs are `NSToolbar` items, outside
/// SwiftUI's focus system — `.focusEffectDisabled()` and the `Tab` API were both
/// measured against it and neither touched it. Clearing `focusRingType` is the
/// one lever that reaches them, and it removes only the drawing: Tab still moves
/// through the tabs and Space still selects one.
///
/// The walk deliberately stops at the content view, so every control *inside* a
/// panel keeps its focus ring — that is the half worth having.
private struct TabBarFocusRingSuppressor: NSViewRepresentable {
    /// Changes when the tab bar is rebuilt, so the walk runs again.
    var trigger: SettingsTab

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        // A hop, because the toolbar's views are not in place yet on the pass
        // that SwiftUI adds this one.
        DispatchQueue.main.async {
            guard let window = view.window, let frame = window.contentView?.superview else { return }
            suppress(in: frame, stoppingAt: window.contentView)
        }
    }

    private func suppress(in view: NSView, stoppingAt content: NSView?) {
        if view === content { return }
        view.focusRingType = .none
        for subview in view.subviews { suppress(in: subview, stoppingAt: content) }
    }
}

private struct GeneralSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Form {
            Section(loc("settings.language.section")) {
                LanguagePicker()
            }

            Section(loc("settings.remember.section")) {
                @Bindable var app = app
                Toggle(loc("settings.remember.mode"), isOn: $app.remembersMode)
                Toggle(loc("settings.remember.engine"), isOn: $app.remembersEngine)
                Toggle(loc("settings.remember.sampling"), isOn: $app.remembersSampling)
                Toggle(loc("settings.remember.output"), isOn: $app.remembersOutput)
                Text(loc("settings.remember.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(loc("settings.notifications")) {
                NotificationPermissionRow()
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("settings.notifications.note"))
                    Text(loc("settings.notifications.focusNote"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section(loc("settings.folders")) {
                LabeledContent(loc("settings.folder.models")) {
                    HStack {
                        Text(app.modelStore.rootURL.path(percentEncoded: false))
                            .lineLimit(1).truncationMode(.middle)
                        Button(loc("models.change")) { chooseModels() }
                    }
                }
                LabeledContent(loc("settings.folder.output")) {
                    HStack {
                        Text(app.library.outputFolder.path(percentEncoded: false))
                            .lineLimit(1).truncationMode(.middle)
                        Button(loc("models.change")) { chooseOutput() }
                    }
                }
            }

            Section(loc("section.queue")) {
                Text(loc("settings.queue.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func chooseModels() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = app.modelStore.rootURL
        if panel.runModal() == .OK, let url = panel.url { app.modelStore.setRoot(url) }
    }

    private func chooseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = app.library.outputFolder
        if panel.runModal() == .OK, let url = panel.url { app.library.outputFolder = url }
    }
}

private struct RuntimeSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Form {
            Section(loc("settings.status")) {
                switch app.runtime.phase {
                case .ready(let report):
                    LabeledContent(loc("settings.python"), value: report.pythonVersion)
                    LabeledContent(loc("settings.architecture"), value: report.machine)
                    LabeledContent(loc("settings.mlxMetal"),
                                   value: report.mlxMetalOK ? loc("settings.working")
                                                            : loc("settings.notWorking"))
                    LabeledContent("ffmpeg", value: report.ffmpegPath ?? loc("settings.notFound"))
                    LabeledContent(loc("settings.h3Pipeline"),
                                   value: report.h3Usable ? loc("settings.detected")
                                                          : loc("settings.notDetected"))
                    ForEach(report.problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                case .installing(let step, _):
                    LabeledContent(loc("settings.state"), value: step)
                case .failed(let message):
                    Label(message, systemImage: "xmark.octagon").foregroundStyle(.red)
                case .missing:
                    Text(loc("settings.notInstalled"))
                case .unknown:
                    Text(loc("status.checking"))
                }
            }

            Section {
                HStack {
                    Button(loc("settings.recheck")) { Task { await app.runtime.runDoctor() } }
                    Button(loc("settings.repair")) { Task { await app.runtime.install() } }
                    Button(loc("settings.rebuild"), role: .destructive) {
                        Task { await app.runtime.install(reinstall: true) }
                    }
                }
                .disabled(app.runtime.phase.isBusy)

                Text(loc("settings.runtime.rebuild.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !app.runtime.installLog.isEmpty {
                LogSection(lines: app.runtime.installLog) { app.runtime.clearLog() }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AdvancedSettings: View {
    @AppStorage("h3RepoOverride") private var repoOverride = ""

    var body: some View {
        Form {
            Section(loc("settings.advanced.port")) {
                // No prompt: the hint below already says what an empty field
                // means, and as placeholder text it printed the same sentence
                // twice, one above the other.
                TextField(loc("settings.advanced.checkout"), text: $repoOverride)
                Text(loc("settings.advanced.checkout.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(loc("settings.folders")) {
                Button(loc("settings.advanced.reveal")) {
                    NSWorkspace.shared.activateFileViewerSelecting([RuntimeManager.supportDirectory])
                }
                Text(loc("settings.advanced.support.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// ComfyUI is a second, separate runtime: it needs PyTorch, which cannot share an
/// environment with MLX, and the user's own ComfyUI must be left alone.
private struct ComfyUISettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Form {
            Section(loc("settings.status")) {
                switch app.comfyRuntime.phase {
                case .ready(let version):
                    LabeledContent("ComfyUI", value: version)
                    LabeledContent(loc("settings.comfy.server"),
                                   value: app.comfyRuntime.isServerRunning
                                        ? loc("settings.comfy.running", "\(app.comfyRuntime.port)")
                                        : loc("settings.comfy.notRunning"))
                case .installing(let step):
                    LabeledContent(loc("settings.state"), value: step)
                case .failed(let message):
                    Label(message, systemImage: "xmark.octagon").foregroundStyle(.red)
                case .missing:
                    Text(loc("settings.notInstalled"))
                case .unknown:
                    Text(loc("status.checking"))
                }
                LabeledContent(loc("settings.comfy.weights"), value: app.comfyRuntime.modelsRoot.path)
                    .textSelection(.enabled)
            }

            Section {
                Text(loc("settings.comfy.why"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button(loc("settings.comfy.install")) { Task { await app.comfyRuntime.install() } }
                        .disabled(app.comfyRuntime.phase.isBusy || app.comfyRuntime.isInstalled)
                    Button(loc("settings.repair")) { Task { await app.comfyRuntime.install() } }
                        .disabled(app.comfyRuntime.phase.isBusy || !app.comfyRuntime.isInstalled)
                    Button(loc("settings.comfy.stop"), role: .destructive) {
                        Task { await app.comfyRuntime.stopServer() }
                    }
                    .disabled(!app.comfyRuntime.isServerRunning)
                }
                Text(loc("settings.comfy.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !app.comfyRuntime.installLog.isEmpty {
                LogSection(lines: app.comfyRuntime.installLog) { app.comfyRuntime.clearLog() }
            }
        }
        .formStyle(.grouped)
    }
}

/// A log, with the two things anyone ever wants to do with one.
///
/// Copy takes the whole log rather than what is on screen: the view keeps only
/// the last 120 lines and truncates each to one line, which is right for reading
/// and useless for pasting into a bug report.
private struct LogSection: View {
    var lines: [String]
    var clear: () -> Void

    @State private var copied = false

    var body: some View {
        Section {
            LogTail(lines: lines)
        } header: {
            HStack {
                Text(loc("settings.log"))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
                    copied = true
                } label: {
                    Label(copied ? loc("library.copied") : loc("common.copy"),
                          systemImage: copied ? "checkmark" : "document.on.document")
                }
                Button(role: .destructive) {
                    clear()
                    copied = false
                } label: {
                    Label(loc("settings.log.clear"), systemImage: "trash")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .labelStyle(.titleAndIcon)
        }
        // Back to "Copy" on its own, so the tick does not sit there implying the
        // clipboard still holds this log long after it might not.
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

/// Interface language, defaulting to whatever the system asks for.
private struct LanguagePicker: View {
    @Environment(Localization.self) private var localization

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(loc("settings.language.label"), selection: Binding(
                get: { localization.preference },
                set: { localization.set($0) })) {
                Text(loc("settings.language.system", localization.systemResolution.endonym))
                    .tag(LanguagePreference.system)
                Divider()
                ForEach(AppLanguage.allCases) { language in
                    // Each language names itself: someone who cannot read the
                    // current interface still has to be able to find their own.
                    Text(language.endonym).tag(LanguagePreference.explicit(language))
                }
            }

            if localization.needsRelaunch {
                Label(loc(localization.directionWillChange ? "settings.language.restart.direction"
                                                           : "settings.language.restart"),
                      systemImage: "arrow.clockwise.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(loc("settings.language.relaunch")) { localization.relaunch() }
                    .controlSize(.small)
            }
        }
    }
}

/// Settings ▸ Cache: what is on disk that can go, and a button to make it go.
private struct CacheSettings: View {
    @Environment(AppState.self) private var app
    @State private var inventory = CacheInventory()
    @State private var working = false

    /// Deleting these mid-render would pull files out from under the job: the
    /// scratch directory *is* the render's working space, and ComfyUI is reading
    /// its own input folder. A download is rebuilding the runtime the uv cache
    /// feeds. So the whole tab waits rather than trying to be clever per row.
    private var isBusy: Bool {
        app.engine.isRunning || app.downloads.transfers.contains { !$0.state.isTerminal }
    }

    var body: some View {
        Form {
            Section {
                ForEach(inventory.categories) { category in
                    LabeledContent {
                        HStack(spacing: 8) {
                            Text(category.bytes > 0
                                 ? Format.bytes(category.bytes)
                                 : loc("settings.cache.empty"))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Button(loc("settings.log.clear")) {
                                Task { await run { await inventory.clear(category) } }
                            }
                            .disabled(isBusy || working || category.bytes == 0)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc(category.titleKey))
                            Text(loc(category.detailKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } header: {
                Text(loc("settings.cache"))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("settings.cache.note"))
                    if isBusy { Text(loc("settings.cache.busy")).foregroundStyle(.orange) }
                    HStack {
                        if inventory.isMeasuring || working { ProgressView().controlSize(.small) }
                        Spacer()
                        Text(Format.bytes(inventory.totalBytes)).monospacedDigit()
                        Button(loc("settings.cache.clearAll")) {
                            Task { await run { await inventory.clearAll() } }
                        }
                        .disabled(isBusy || working || inventory.totalBytes == 0)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        // Measured on appearance rather than kept live: walking a 3 GB directory
        // is not something to repeat on a timer for a tab nobody is looking at.
        .task { await inventory.refresh() }
    }

    private func run(_ work: () async -> Void) async {
        working = true
        await work()
        working = false
    }
}

/// Settings ▸ Requirements: the same two tables the welcome dialog shows, so the
/// answer stays reachable after onboarding has been dismissed and forgotten.
///
/// Both together because they are one question asked twice. The disk figure
/// depends on the memory figure — whatever a render cannot hold gets paged out —
/// so a reader who sees only one of them draws the wrong conclusion from it.
private struct RequirementsSettings: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("settings.memory")).font(.headline)
                    MemoryRequirementsTable()
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("settings.disk")).font(.headline)
                    DiskRequirementsTable()
                }
            }
            .padding(20)
        }
    }
}
