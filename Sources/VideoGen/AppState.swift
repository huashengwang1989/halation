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
            case .compose: "Compose"
            case .queue: "Queue"
            case .library: "Library"
            case .models: "Models"
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
    var draft = GenerationSpec()
    var showingOnboarding = false
    /// Incremented when the user asks why Generate is unavailable. The summary
    /// observes it to scroll to and flash the blocking-issues card.
    private(set) var problemFocusPulse = 0

    func highlightProblems() { problemFocusPulse += 1 }
    var licenseAcknowledged: Bool {
        didSet { UserDefaults.standard.set(licenseAcknowledged, forKey: "licenseAcknowledged") }
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
        self.licenseAcknowledged = UserDefaults.standard.bool(forKey: "licenseAcknowledged")

        // Start on the recommended preset rather than an empty form.
        if let preset = GenerationPreset.builtIns.first {
            draft = preset.spec
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

        let transformerMissing = draft.transformerEntryID.map { !installed.contains($0) } ?? true
        if transformerMissing {
            draft.transformerEntryID = ModelCatalog.transformers(task: task)
                .first { installed.contains($0.id) }?.id
        }
        let encoderMissing = draft.textEncoderEntryID.map { !installed.contains($0) } ?? true
        if encoderMissing {
            draft.textEncoderEntryID = ModelCatalog.entries(role: .textEncoder)
                .filter { installed.contains($0.id) }
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
