import Foundation

/// Which engine produced, or will produce, a render.
enum BackendID: String, Codable, Sendable, CaseIterable, Identifiable {
    /// The MLX port. Fast, native, keyframes only.
    case mlx
    /// A headless ComfyUI on PyTorch/Metal. Slower per step, but it is the only
    /// path that implements reference conditioning, and it can load LoRAs.
    case comfyUI

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mlx: "MLX"
        case .comfyUI: "ComfyUI"
        }
    }

    var detail: String {
        switch self {
        case .mlx:
            "Apple's own framework, running the model natively. Text-to-video and "
            + "keyframes only — the port has no reference conditioning."
        case .comfyUI:
            "PyTorch on Metal. The only backend that supports references, and the "
            + "only one that can load the 4-step turbo LoRAs."
        }
    }
}

/// A source of rendered video.
///
/// Both backends report through `SidecarEvent`, so everything above this line —
/// the queue, progress, ETAs, the library — is unaware of which produced a clip.
protocol RenderBackend: Sendable {
    var id: BackendID { get }

    /// Whether this backend implements a mode at all.
    func supports(_ mode: GenerationMode) -> Bool

    /// Anything preventing a render right now: runtime missing, models absent.
    /// `nil` means ready.
    @MainActor func unavailableReason(for spec: GenerationSpec) -> String?

    /// Produces a video file, reporting progress as it goes.
    ///
    /// - Returns: the raw render, before `VideoPostProcessor` applies the
    ///   delivery format.
    func run(spec: GenerationSpec,
             scratch: URL,
             events: @escaping @Sendable (SidecarEvent) -> Void) async throws -> URL

    /// Stops an in-flight render.
    func cancel() async
}

// MARK: - MLX

/// Drives the Python sidecar around `minimax-h3-mlx`.
///
/// This is the original path, unchanged in behaviour; it simply lives behind the
/// protocol now so a second backend can exist beside it.
actor MLXBackend: RenderBackend {
    nonisolated var id: BackendID { .mlx }

    private let runtime: RuntimeManager
    private let modelStore: ModelStore
    private var runner: ProcessRunner?

    init(runtime: RuntimeManager, modelStore: ModelStore) {
        self.runtime = runtime
        self.modelStore = modelStore
    }

    nonisolated func supports(_ mode: GenerationMode) -> Bool {
        // The MLX pipeline's __call__ takes keyframes only: it has no
        // reference-image, video or audio parameter.
        mode != .reference
    }

    @MainActor func unavailableReason(for spec: GenerationSpec) -> String? {
        guard runtime.phase.isReady else {
            return "The Python runtime is not ready. Open Settings › Runtime."
        }
        guard let id = spec.transformerEntryID, let entry = ModelCatalog.entry(id: id),
              modelStore.isInstalled(entry) else {
            return "The selected checkpoint is not installed."
        }
        return nil
    }

    func run(spec: GenerationSpec,
             scratch: URL,
             events: @escaping @Sendable (SidecarEvent) -> Void) async throws -> URL {
        let rawOutput = scratch.appending(path: "render.mp4")
        let jobFile = scratch.appending(path: "job.json")
        try await MainActor.run {
            try JobFileWriter(modelStore: modelStore)
                .write(spec: spec, rawOutput: rawOutput, to: jobFile)
        }

        let runner = ProcessRunner()
        self.runner = runner

        let pythonURL = await runtime.pythonURL
        let scriptPath = await runtime.sidecarScript.path
        let environment = await runtime.environment()

        var produced: URL?
        var failure: String?

        let stream = await runner.lines(.init(
            executable: pythonURL,
            arguments: [scriptPath, "generate", "--job", jobFile.path],
            environment: environment))

        for try await line in stream {
            guard let event = SidecarEvent.parse(line: line) else { continue }
            if case .artifact(let video, _) = event { produced = video }
            if case .failure(let message) = event { failure = message }
            events(event)
        }

        if let failure { throw BackendError.reported(failure) }
        guard let produced, FileManager.default.fileExists(atPath: produced.path) else {
            throw BackendError.noOutput
        }
        return produced
    }

    func cancel() async {
        await runner?.terminate()
    }
}

enum BackendError: LocalizedError {
    case reported(String)
    case noOutput
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .reported(let message): message
        case .noOutput: "The render finished but produced no video file."
        case .unsupported(let reason): reason
        }
    }
}
