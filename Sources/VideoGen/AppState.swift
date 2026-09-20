import Foundation
import Observation
import SwiftUI

/// Wires the stores together and holds the small amount of state that is genuinely
/// app-wide: which tab is showing, and whether first-run setup is still pending.
@MainActor
@Observable
final class AppState {
    let modelStore: ModelStore
    let runtime: RuntimeManager
    let comfyRuntime: ComfyUIRuntime
    let library: LibraryStore
    let downloads: DownloadManager
    let engine: RenderEngine

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case compose, queue, library, models

        var id: String { rawValue }

        var label: String {
            switch self {
            case .compose: loc("section.compose")
            case .queue: loc("section.queue")
            case .library: loc("section.library")
            case .models: loc("section.models")
            }
        }

        var symbolName: String {
            switch self {
            case .compose: "wand.and.sparkles"
            case .queue: "list.bullet.rectangle"
            case .library: "film.stack"
            case .models: "cube.box"
            }
        }
    }

    var section: Section = .compose
    /// The spec currently being edited in Compose.
    ///
    /// The observer keeps the mode and engine across launches. Only those two:
    /// the prompt, the seed and the attached files belong to one particular
    /// render, while the mode and the engine are how someone works.
    var draft = GenerationSpec() {
        didSet { rememberDraftChoices(replacing: oldValue) }
    }
    var showingOnboarding = false
    /// Incremented when the user asks why Generate is unavailable. The summary
    /// observes it to scroll to and flash the blocking-issues card.
    private(set) var problemFocusPulse = 0

    func highlightProblems() { problemFocusPulse += 1 }

    /// Bumped after a preset is saved, so the control that now holds it draws the
    /// eye. SwiftUI cannot open a `Menu` on demand, and a menu that opened by
    /// itself would have to be dismissed again anyway; pointing at the control is
    /// the part that answers "where did that go?".
    private(set) var presetSavedPulse = 0

    func highlightPresets() { presetSavedPulse += 1 }

    /// A short-lived message for the status bar — a delete confirming itself, say.
    private(set) var note: String?

    func note(_ message: String) {
        note = message
        Task {
            try? await Task.sleep(for: .seconds(6))
            if note == message { note = nil }
        }
    }
    var licenseAcknowledged: Bool {
        didSet { UserDefaults.standard.set(licenseAcknowledged, forKey: "licenseAcknowledged") }
    }

    /// Whether Compose opens on the mode and engine last used.
    ///
    /// On by default, because carrying on where you left off is what people
    /// expect; the switches in Settings are for anyone who would rather each
    /// session start from the same place.
    var remembersMode: Bool {
        didSet {
            UserDefaults.standard.set(remembersMode, forKey: Self.remembersModeKey)
            if remembersMode { rememberDraftChoices(replacing: nil) }
        }
    }

    var remembersEngine: Bool {
        didSet {
            UserDefaults.standard.set(remembersEngine, forKey: Self.remembersEngineKey)
            if remembersEngine { rememberDraftChoices(replacing: nil) }
        }
    }

    /// Duration and steps. Kept as a group, because they are read together and
    /// nobody thinks about them one at a time.
    var remembersSampling: Bool {
        didSet {
            UserDefaults.standard.set(remembersSampling, forKey: Self.remembersSamplingKey)
            if remembersSampling { rememberDraftChoices(replacing: nil) }
        }
    }

    /// Aspect ratio, resolution, frame rate, codec and audio handling.
    var remembersOutput: Bool {
        didSet {
            UserDefaults.standard.set(remembersOutput, forKey: Self.remembersOutputKey)
            if remembersOutput { rememberDraftChoices(replacing: nil) }
        }
    }

    private static let remembersModeKey = "remembersMode"
    private static let remembersEngineKey = "remembersEngine"
    private static let remembersSamplingKey = "remembersSampling"
    private static let remembersOutputKey = "remembersOutput"
    private static let lastModeKey = "lastComposeMode"
    private static let lastEngineKey = "lastComposeEngine"
    private static let lastSamplingKey = "lastComposeSampling"
    private static let lastOutputKey = "lastComposeOutput"

    /// Writes the mode and engine, when they have changed and are being kept.
    ///
    /// `replacing: nil` means "write them regardless", which is what turning a
    /// switch back on should do — otherwise the choice on screen would not be
    /// recorded until it was next changed.
    private func rememberDraftChoices(replacing previous: GenerationSpec?) {
        let defaults = UserDefaults.standard
        func changed<Value: Equatable>(_ path: KeyPath<GenerationSpec, Value>) -> Bool {
            previous.map { $0[keyPath: path] != draft[keyPath: path] } ?? true
        }

        if remembersMode, changed(\.mode) {
            defaults.set(draft.mode.rawValue, forKey: Self.lastModeKey)
        }
        if remembersEngine, changed(\.backend) {
            // Nil is a real choice — it means "whatever suits this mode" — so it
            // is stored as the absence of the key rather than as a value.
            if let backend = draft.backend {
                defaults.set(backend.rawValue, forKey: Self.lastEngineKey)
            } else {
                defaults.removeObject(forKey: Self.lastEngineKey)
            }
        }
        if remembersSampling, changed(\.sampling) {
            var sampling = draft.sampling
            // A fixed seed is one particular clip, not a way of working — the
            // same reason `savePreset` drops it from a preset.
            sampling.seed = nil
            if let data = try? JSONEncoder().encode(sampling) {
                defaults.set(data, forKey: Self.lastSamplingKey)
            }
        }
        if remembersOutput, changed(\.format) {
            if let data = try? JSONEncoder().encode(draft.format) {
                defaults.set(data, forKey: Self.lastOutputKey)
            }
        }
    }

    init() {
        let modelStore = ModelStore()
        let runtime = RuntimeManager(modelStore: modelStore)
        let comfyRuntime = ComfyUIRuntime(modelStore: modelStore)
        let library = LibraryStore()
        self.modelStore = modelStore
        self.runtime = runtime
        self.comfyRuntime = comfyRuntime
        self.library = library
        self.downloads = DownloadManager(runtime: runtime, modelStore: modelStore)
        self.engine = RenderEngine(runtime: runtime, comfyRuntime: comfyRuntime,
                                   modelStore: modelStore, library: library)
        let defaults = UserDefaults.standard
        self.licenseAcknowledged = defaults.bool(forKey: "licenseAcknowledged")
        // Absent means on: remembering is the default, so a fresh install does it.
        self.remembersMode = defaults.object(forKey: Self.remembersModeKey) as? Bool ?? true
        self.remembersEngine = defaults.object(forKey: Self.remembersEngineKey) as? Bool ?? true
        self.remembersSampling = defaults.object(forKey: Self.remembersSamplingKey) as? Bool ?? true
        self.remembersOutput = defaults.object(forKey: Self.remembersOutputKey) as? Bool ?? true

        // Start on the recommended preset rather than an empty form.
        if let preset = GenerationPreset.builtIns.first {
            draft = preset.spec
        }

        // Then put back however the user last left it. Property observers do not
        // run during init, so nothing is written back here.
        if remembersMode,
           let raw = defaults.string(forKey: Self.lastModeKey),
           let mode = GenerationMode(rawValue: raw) {
            draft.mode = mode
        }
        if remembersEngine {
            draft.backend = defaults.string(forKey: Self.lastEngineKey)
                .flatMap(BackendID.init(rawValue:))
        }
        if remembersSampling, let data = defaults.data(forKey: Self.lastSamplingKey),
           let sampling = try? JSONDecoder().decode(SamplingSettings.self, from: data) {
            draft.sampling = sampling
        }
        if remembersOutput, let data = defaults.data(forKey: Self.lastOutputKey),
           let format = try? JSONDecoder().decode(OutputFormat.self, from: data) {
            draft.format = format
        }
    }

    /// Cheap checks first, then the slow ones.
    ///
    /// The runtime check spawns Python and imports MLX, which takes the better part
    /// of a quarter-minute from cold. Deciding to show onboarding only after that
    /// would leave a first-time user looking at an empty window, so anything we can
    /// answer from disk is answered up front and the sheet is raised immediately.
    func bootstrap() async {
        if !licenseAcknowledged || !runtime.isInstalled {
            showingOnboarding = true
        }

        await modelStore.scan()
        if modelStore.installedEntryIDs.isEmpty { showingOnboarding = true }
        selectBestAvailableModels()

        await runtime.refresh()
        await comfyRuntime.refresh()
        selectBestAvailableModels()
        if !runtime.phase.isReady { showingOnboarding = true }

        engine.startNextIfIdle()
    }

    /// Picks the highest-quality installed checkpoint for the draft's task, so the
    /// user is never staring at an unset model picker.
    func selectBestAvailableModels() {
        let installed = modelStore.installedEntryIDs
        let task = draft.task
        let backend = draftBackend

        // A selection stays only if it still belongs to the task *and* the engine
        // now chosen — being installed is not enough. Checking installedness alone
        // meant switching to reference mode kept an installed FL2VA transformer,
        // and switching engine kept weights the new engine cannot read at all.
        func stillFits(_ id: String?, matchingTask: Bool) -> Bool {
            guard let id, installed.contains(id),
                  let entry = ModelCatalog.entry(id: id),
                  entry.backend == backend
            else { return false }
            return matchingTask ? entry.task == task : true
        }

        if !stillFits(draft.transformerEntryID, matchingTask: true) {
            draft.transformerEntryID = ModelCatalog.transformers(task: task)
                .first { installed.contains($0.id) && $0.backend == backend }?.id
        }
        if !stillFits(draft.textEncoderEntryID, matchingTask: false) {
            draft.textEncoderEntryID = ModelCatalog.entries(role: .textEncoder)
                .filter { installed.contains($0.id) && $0.backend == backend }
                .min { $0.approximateBytes < $1.approximateBytes }?.id
        }
    }

    var draftProblems: [GenerationSpec.Problem] {
        draft.validate(installed: modelStore.installedEntryIDs)
    }

    var canGenerate: Bool {
        engine.unavailableReason(for: draft) == nil
            && !draftProblems.contains { $0.severity == .blocking }
    }

    /// The engine that will serve the draft, for display in Compose.
    var draftBackend: BackendID { engine.backend(for: draft).id }

    /// A sensible step count for a mode, given the engine and whether a turbo
    /// LoRA is installed for it.
    func recommendedSteps(for mode: GenerationMode) -> Int {
        var probe = draft
        probe.mode = mode
        guard engine.backend(for: probe).id == .comfyUI else { return 16 }
        let lora = ComfyUIModelSet.turboLoRA(for: mode.task)
        let present = FileManager.default.fileExists(
            atPath: modelStore.rootURL
                .appending(path: "comfyui/loras/\(lora)").path)
        return ComfyUIModelSet.recommendedSteps(hasTurboLoRA: present)
    }

    func generate() {
        guard canGenerate else { return }
        _ = engine.enqueue(draft)
        section = .queue
    }

    func apply(preset: GenerationPreset) {
        var spec = preset.spec
        // Keep whatever the user has already typed and attached.
        spec.prompt = draft.prompt
        spec.references = draft.references
        spec.mode = draft.mode
        draft = spec
        selectBestAvailableModels()
    }
}
