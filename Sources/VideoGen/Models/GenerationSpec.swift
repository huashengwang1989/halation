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
        case .textToVideo: "Text to video"
        case .firstFrame: "First frame"
        case .firstAndLastFrame: "First & last frame"
        case .reference: "References"
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
        case .textToVideo:
            "Generate purely from a written description."
        case .firstFrame:
            "Animate outward from a still image you supply."
        case .firstAndLastFrame:
            "Supply both ends of the shot; the model fills in the motion between them."
        case .reference:
            "Supply reference images, clips or audio to pin down a subject, style or voice."
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
            case .image: "Image"
            case .video: "Video"
            case .audio: "Audio"
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
            case .first: "First frame"
            case .last: "Last frame"
            case .reference: "Reference"
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
    /// Denoising steps. 8 is the low-step preview point; 50 is the card's default.
    var steps: Int = 16
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
    func estimatedDuration(quantization: Quantization,
                           pixels: Int,
                           bandwidthFactor: Double = 1.5) -> ClosedRange<TimeInterval> {
        // Published anchor: bf16, 5 s, 8 steps ≈ 1.2 h on M3 Ultra.
        let anchorHours = 1.2
        let stepFactor = Double(steps) / 8.0
        let durationFactor = Double(durationSeconds) / 5.0
        let pixelFactor = Double(pixels) / Double(1344 * 768)

        let quantSpeedup: Double = switch quantization {
        case .q4: 1.4
        case .q6: 1.25
        case .q8: 1.1
        default: 1.0
        }

        let centre = anchorHours * stepFactor * durationFactor * pixelFactor
                   * bandwidthFactor / quantSpeedup * 3600
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
    var transformerEntryID: String?
    /// Catalog id of the text encoder to load.
    var textEncoderEntryID: String?

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
            problems.append(.init(severity: .blocking, message: "Write a prompt describing the shot."))
        }

        if !SamplingSettings.durationRange.contains(sampling.durationSeconds) {
            problems.append(.init(severity: .blocking,
                message: "H3 only generates 4–15 second clips."))
        }

        // Mode-specific input requirements.
        let images = references.filter { $0.kind == .image }
        switch mode {
        case .textToVideo:
            if !references.isEmpty {
                problems.append(.init(severity: .advisory,
                    message: "Text-to-video ignores attached files. Switch modes to use them."))
            }
        case .firstFrame:
            if images.isEmpty {
                problems.append(.init(severity: .blocking, message: "Add a first-frame image."))
            }
        case .firstAndLastFrame:
            let hasFirst = references.contains { $0.slot == .first }
            let hasLast = references.contains { $0.slot == .last }
            if !hasFirst { problems.append(.init(severity: .blocking, message: "Add a first-frame image.")) }
            if !hasLast { problems.append(.init(severity: .blocking, message: "Add a last-frame image.")) }
        case .reference:
            if references.isEmpty {
                problems.append(.init(severity: .blocking,
                    message: "Ref2VA needs at least one reference file."))
            }
            for (kind, group) in references0fKind where group.count > kind.limit {
                problems.append(.init(severity: .blocking,
                    message: "At most \(kind.limit) reference \(kind.label.lowercased()) files — you have \(group.count)."))
            }
            if references.count > ReferenceAsset.totalFileLimit {
                problems.append(.init(severity: .blocking,
                    message: "Ref2VA accepts \(ReferenceAsset.totalFileLimit) reference files in total."))
            }
        }

        // Installed-model requirements.
        if let id = transformerEntryID {
            if !installed.contains(id) {
                problems.append(.init(severity: .blocking,
                    message: "The selected checkpoint isn't installed yet."))
            }
            if let entry = ModelCatalog.entry(id: id), !entry.isUsableHere {
                problems.append(.init(severity: .blocking,
                    message: "\(entry.quantization.label) has no Metal kernel and cannot run on Apple silicon."))
            }
        } else {
            problems.append(.init(severity: .blocking,
                message: "Choose a \(task.rawValue) checkpoint in Models."))
        }

        if format.resolution.isUpscale {
            problems.append(.init(severity: .advisory,
                message: "\(format.resolution.label) is a resample of the model's 768p output. "
                       + "H3's true 2K mode is not open-sourced and cannot run locally."))
        }

        if mode == .reference {
            problems.append(.init(severity: .blocking,
                message: "The MLX port does not implement reference conditioning yet — its "
                       + "pipeline accepts keyframes only. Ref2VA needs the CUDA stack "
                       + "(SGLang, vLLM or ComfyUI) for now."))
        }

        if sampling.steps < 8 {
            problems.append(.init(severity: .advisory,
                message: "Below 8 steps the model tends to produce soft, unstable motion."))
        }

        if sampling.durationSeconds > 8, sampling.steps > 20 {
            problems.append(.init(severity: .advisory,
                message: "Long clips at high step counts can run overnight. Consider a short test first."))
        }

        return problems
    }

    var isRenderable: Bool { true }
}

/// A named, reusable spec. This is the "save the generate video function" feature:
/// a recipe you can recall, not just a saved file.
struct GenerationPreset: Codable, Sendable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var spec: GenerationSpec
    var createdAt: Date = .now
    /// Presets shipped with the app cannot be deleted, only duplicated.
    var isBuiltIn: Bool = false

    static let builtIns: [GenerationPreset] = [
        GenerationPreset(
            name: "Fast preview",
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
