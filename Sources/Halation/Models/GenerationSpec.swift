import Foundation

enum GenerationMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Prompt only.
    case textToVideo
    /// Prompt plus a first frame.
    case firstFrame
    /// Prompt plus first and last frames; the model interpolates between them.
    case firstAndLastFrame
    /// Prompt plus reference images/videos/audio that define subject and style.
    case reference

    var id: String { rawValue }

    var label: String {
        switch self {
        case .textToVideo: loc("mode.t2v")
        case .firstFrame: loc("mode.first")
        case .firstAndLastFrame: loc("mode.firstlast")
        case .reference: loc("mode.reference")
        }
    }

    var symbolName: String {
        switch self {
        case .textToVideo: "text.bubble"
        case .firstFrame: "photo"
        case .firstAndLastFrame: "photo.on.rectangle.angled"
        case .reference: "square.stack.3d.up"
        }
    }

    var detail: String {
        switch self {
        case .textToVideo: loc("mode.t2v.detail")
        case .firstFrame: loc("mode.first.detail")
        case .firstAndLastFrame: loc("mode.firstlast.detail")
        case .reference: loc("mode.reference.detail")
        }
    }

    var task: ModelTask { self == .reference ? .ref2va : .fl2va }

    var maxImages: Int {
        switch self {
        case .textToVideo: 0
        case .firstFrame: 1
        case .firstAndLastFrame: 2
        case .reference: 9
        }
    }
}

/// A reference input attached to a job.
struct ReferenceAsset: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case image, video, audio

        var label: String {
            switch self {
            case .image: loc("refs.kind.image")
            case .video: loc("refs.kind.video")
            case .audio: loc("refs.kind.audio")
            }
        }

        var symbolName: String {
            switch self {
            case .image: "photo"
            case .video: "film"
            case .audio: "waveform"
            }
        }

        /// Ref2VA caps each kind separately, and all kinds together at 12 files.
        var limit: Int {
            switch self {
            case .image: 9
            case .video: 3
            case .audio: 3
            }
        }
    }

    /// Where this asset sits in the conditioning order. For `firstAndLastFrame`,
    /// slot 0 is the first frame and slot 1 the last.
    enum Slot: String, Codable, Sendable {
        case first, last, reference

        var label: String {
            switch self {
            case .first: loc("refs.slot.first")
            case .last: loc("refs.slot.last")
            case .reference: loc("refs.slot.reference")
            }
        }
    }

    var id: UUID = UUID()
    var url: URL
    var kind: Kind
    var slot: Slot = .reference

    static let totalFileLimit = 12
}

/// Model-side sampling parameters, as opposed to delivery formatting.
struct SamplingSettings: Codable, Sendable, Hashable {
    /// 4–15 s, per the model card.
    var durationSeconds: Int = 5
    /// Denoising steps, meaning **actual forward passes**.
    ///
    /// The engines disagree on what "steps" counts. The MLX port takes a count of
    /// sigma-grid points and runs one fewer forward pass than that; ComfyUI's
    /// BasicScheduler runs exactly the number given. This value is the forward
    /// passes, and each backend converts on the way out — so the same number is
    /// the same amount of work whichever engine runs it.
    var steps: Int = 16

    /// What the MLX sidecar must be told to achieve `steps` forward passes.
    var mlxSigmaPoints: Int { steps + 1 }
    /// `nil` means "pick a fresh random seed for each run".
    var seed: Int64?

    // H3's released weights are CFG-distilled — each step is a single forward pass —
    // so there is no guidance scale and no negative prompt to expose. Offering
    // either would be a control that silently does nothing.

    static let durationRange = 5...15
    static let stepsRange = 4...60

    /// The duration actually rendered, after snapping to the VAE's frame grid.
    var effectiveSeconds: Double { FrameGrid.alignedSeconds(forSeconds: durationSeconds) }
    var frameCount: Int { FrameGrid.alignedFrameCount(forSeconds: durationSeconds) }

    /// Very rough wall-clock estimate, anchored on the MLX port's published M3 Ultra
    /// figures and scaled for this machine's lower memory bandwidth. Presented as a
    /// range because real timings vary a lot with resolution and reference count.
    /// How long this will take, as a range.
    ///
    /// The machine-dependent part is `secondsPerStepMegapixel` and nothing else;
    /// see `RenderThroughput`, which measures it from finished renders where it
    /// can and predicts it from memory bandwidth where it cannot. This used to
    /// carry a constant tuned to one particular Mac, which made the estimate
    /// meaningless anywhere else.
    func estimatedDuration(quantization: Quantization,
                           pixels: Int,
                           secondsPerStepMegapixel: Double) -> ClosedRange<TimeInterval> {
        let centre = secondsPerStepMegapixel
            * RenderThroughput.work(sampling: self, pixels: pixels, quantization: quantization)
        return (centre * 0.7)...(centre * 1.45)
    }
}

/// Everything needed to reproduce one render. This is what gets saved as a preset
/// and what gets written beside the finished file.
struct GenerationSpec: Codable, Sendable, Hashable {
    var prompt: String = ""
    var mode: GenerationMode = .textToVideo
    var sampling = SamplingSettings()
    var format = OutputFormat()
    var references: [ReferenceAsset] = []
    /// Catalog id of the transformer checkpoint to load.
    /// The engine this spec runs on, worked out without the engine itself.
    ///
    /// Mirrors `RenderEngine.backend(for:)`: an explicit choice wins, reference
    /// conditioning exists only in ComfyUI, and everything else is MLX. Reference
    /// specs carry `backend == nil`, so reading that field directly reports them
    /// as MLX renders — which is how finished reference renders went missing from
    /// the throughput measurement.
    var resolvedBackend: BackendID {
        if let backend { return backend }
        return mode == .reference ? .comfyUI : .mlx
    }

    var transformerEntryID: String?
    /// Catalog id of the text encoder to load.
    var textEncoderEntryID: String?
    /// Force a particular engine. `nil` lets the app choose: MLX where it can,
    /// ComfyUI for modes only it implements.
    var backend: BackendID?

    var task: ModelTask { mode.task }

    var references0fKind: [ReferenceAsset.Kind: [ReferenceAsset]] {
        Dictionary(grouping: references, by: \.kind)
    }

    // MARK: - Validation

    struct Problem: Identifiable, Sendable, Hashable {
        enum Severity: Sendable, Hashable { case blocking, advisory }
        var id = UUID()
        var severity: Severity
        var message: String
    }

    /// Everything wrong with this spec. A non-empty `blocking` set disables Generate.
    func validate(installed: Set<String>) -> [Problem] {
        var problems: [Problem] = []

        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append(.init(severity: .blocking, message: loc("problem.prompt.empty")))
        }

        if !SamplingSettings.durationRange.contains(sampling.durationSeconds) {
            problems.append(.init(severity: .blocking,
                message: loc("problem.duration")))
        }

        // Mode-specific input requirements.
        let images = references.filter { $0.kind == .image }
        switch mode {
        case .textToVideo:
            if !references.isEmpty {
                problems.append(.init(severity: .advisory,
                    message: loc("problem.t2v.extraFiles")))
            }
        case .firstFrame:
            if images.isEmpty {
                problems.append(.init(severity: .blocking, message: loc("problem.needFirst")))
            }
        case .firstAndLastFrame:
            let hasFirst = references.contains { $0.slot == .first }
            let hasLast = references.contains { $0.slot == .last }
            if !hasFirst { problems.append(.init(severity: .blocking, message: loc("problem.needFirst"))) }
            if !hasLast { problems.append(.init(severity: .blocking, message: loc("problem.needLast"))) }
        case .reference:
            if references.isEmpty {
                problems.append(.init(severity: .blocking,
                    message: loc("problem.needReference")))
            }
            for (kind, group) in references0fKind where group.count > kind.limit {
                problems.append(.init(severity: .blocking,
                    message: loc("problem.tooManyOfKind", "\(kind.limit)",
                                 kind.label.lowercased(), "\(group.count)")))
            }
            if references.count > ReferenceAsset.totalFileLimit {
                problems.append(.init(severity: .blocking,
                    message: loc("problem.tooManyTotal", "\(ReferenceAsset.totalFileLimit)")))
            }
        }

        // Installed-model requirements.
        if let id = transformerEntryID {
            if !installed.contains(id) {
                problems.append(.init(severity: .blocking,
                    message: loc("problem.notInstalled")))
            }
            if let entry = ModelCatalog.entry(id: id), !entry.isUsableHere {
                problems.append(.init(severity: .blocking,
                    message: loc("problem.noMetalKernel", entry.quantization.label)))
            }
        } else {
            problems.append(.init(severity: .blocking,
                message: loc("problem.chooseCheckpoint", task.rawValue)))
        }

        problems.append(contentsOf: memoryProblems)

        if format.resolution.isUpscale {
            problems.append(.init(severity: .advisory,
                message: loc("problem.upscale", format.resolution.label)))
        }

        if mode == .reference {
            // H3 addresses references from the prompt. One that is never named
            // contributes far less, so this is a correctness issue, not a nicety.
            let images = references.filter { $0.kind == .image }
            let untagged = images.indices.filter { !prompt.contains("<Picture \($0 + 1)>") }
            if !untagged.isEmpty {
                let tags = untagged.map { "<Picture \($0 + 1)>" }.joined(separator: ", ")
                problems.append(.init(severity: .advisory,
                    message: loc("problem.refUntagged", tags)))
            }
            problems.append(.init(severity: .advisory,
                message: loc("problem.refSlow")))
        }

        if sampling.steps < 8 {
            problems.append(.init(severity: .advisory,
                message: loc("problem.lowSteps")))
        }

        if sampling.durationSeconds > 8, sampling.steps > 20 {
            problems.append(.init(severity: .advisory,
                message: loc("problem.longOvernight")))
        }

        return problems
    }

    /// Whether the weights this spec selects will fit while it runs.
    ///
    /// Everything the run holds at once has to sit in what the GPU may wire down,
    /// and on Apple Silicon that is a fraction of installed memory rather than all
    /// of it — the rest belongs to the system and to graphics. Advisory rather
    /// than blocking: going over does not fail, it swaps, and whether that is
    /// worth the wait is the user's call on their own machine.
    private var memoryProblems: [Problem] {
        let resident = [transformerEntryID, textEncoderEntryID]
            .compactMap { $0 }
            .compactMap { ModelCatalog.entry(id: $0)?.approximateResidentBytes }
            .reduce(0, +)
        guard resident > MachineProfile.usableWeightBytes else { return [] }
        return [.init(severity: .advisory,
                      message: loc("problem.memory",
                                   Format.bytes(resident),
                                   Format.bytes(MachineProfile.usableWeightBytes)))]
    }

    var isRenderable: Bool { true }
}

/// A named, reusable spec. This is the "save the generate video function" feature:
/// a recipe you can recall, not just a saved file.
struct GenerationPreset: Codable, Sendable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Translation key for a built-in's name. A preset is saved to disk, so the
    /// name it was stored under cannot be the translated text — that would freeze
    /// whichever language happened to be current when it was written. Built-ins
    /// carry the key and are translated on the way to the screen; a preset the
    /// user named keeps the name they typed, in whatever language they typed it.
    var nameKey: String?

    var spec: GenerationSpec
    var createdAt: Date = .now
    /// Presets shipped with the app cannot be deleted, only duplicated.
    var isBuiltIn: Bool = false
    var displayName: String { nameKey.map { loc($0) } ?? name }

    static let builtIns: [GenerationPreset] = [
        GenerationPreset(
            name: "Fast preview",
            nameKey: "preset.fastPreview",
            spec: {
                var spec = GenerationSpec()
                spec.sampling.steps = 16
                spec.sampling.durationSeconds = 5
                spec.format.aspectRatio = .widescreen
                spec.format.resolution = .native768
                return spec
            }(),
            isBuiltIn: true
        ),
        GenerationPreset(
            name: "Quality — overnight",
            nameKey: "preset.quality",
            spec: {
                var spec = GenerationSpec()
                spec.sampling.steps = 50
                spec.sampling.durationSeconds = 5
                spec.format.aspectRatio = .widescreen
                return spec
            }(),
            isBuiltIn: true
        ),
        GenerationPreset(
            name: "Vertical social",
            nameKey: "preset.vertical",
            spec: {
                var spec = GenerationSpec()
                spec.sampling.steps = 12
                spec.sampling.durationSeconds = 6
                spec.format.aspectRatio = .portrait
                spec.format.frameRate = .fps30
                return spec
            }(),
            isBuiltIn: true
        )
    ]
}
