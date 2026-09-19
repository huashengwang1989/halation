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
    var licenseAcknowledged: Bool {
        didSet { UserDefaults.standard.set(licenseAcknowledged, forKey: "licenseAcknowledged") }
    }

    init() {
        let modelStore = ModelStore()
        let runtime = RuntimeManager(modelStore: modelStore)
        let library = LibraryStore()
        self.modelStore = modelStore
        self.runtime = runtime
        self.library = library
        self.downloads = DownloadManager(runtime: runtime, modelStore: modelStore)
        self.engine = RenderEngine(runtime: runtime, modelStore: modelStore, library: library)
        self.licenseAcknowledged = UserDefaults.standard.bool(forKey: "licenseAcknowledged")

        // Start on the recommended preset rather than an empty form.
        if let preset = GenerationPreset.builtIns.first {
            draft = preset.spec
        }
    }

    func bootstrap() async {
        await modelStore.scan()
        await runtime.refresh()
        selectBestAvailableModels()

        let needsRuntime = !runtime.phase.isReady
        let needsModels = modelStore.installedEntryIDs.isEmpty
        showingOnboarding = needsRuntime || needsModels || !licenseAcknowledged

        engine.startNextIfIdle()
    }

    /// Picks the highest-quality installed checkpoint for the draft's task, so the
    /// user is never staring at an unset model picker.
    func selectBestAvailableModels() {
        let installed = modelStore.installedEntryIDs
        let task = draft.task

        if draft.transformerEntryID == nil || !installed.contains(draft.transformerEntryID!) {
            draft.transformerEntryID = ModelCatalog.transformers(task: task)
                .first { installed.contains($0.id) }?.id
        }
        if draft.textEncoderEntryID == nil || !installed.contains(draft.textEncoderEntryID!) {
            draft.textEncoderEntryID = ModelCatalog.entries(role: .textEncoder)
                .filter { installed.contains($0.id) }
                .min { $0.approximateBytes < $1.approximateBytes }?.id
        }
    }

    var draftProblems: [GenerationSpec.Problem] {
        draft.validate(installed: modelStore.installedEntryIDs)
    }

    var canGenerate: Bool {
        runtime.phase.isReady && !draftProblems.contains { $0.severity == .blocking }
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
