import Foundation

/// Which piece of the H3 inference stack a repository provides.
enum ModelRole: String, Codable, Sendable, CaseIterable {
    /// The 33B single-stream diffusion transformer — the part that gets quantized.
    case transformer
    /// Qwen3-VL-32B. H3 takes its 50th-layer hidden states as conditioning.
    case textEncoder
    /// Video VAE, audio VAE, processor, tokenizer and scheduler configs.
    case support
    /// LoRAs that cut the step count.
    case accelerator

    var label: String {
        switch self {
        case .transformer: loc("role.transformer")
        case .textEncoder: loc("role.textEncoder")
        case .support: loc("role.support")
        case .accelerator: loc("role.accelerator")
        }
    }

    var detail: String {
        switch self {
        case .transformer:
            loc("role.transformer.detail")
        case .textEncoder:
            loc("role.textEncoder.detail")
        case .support:
            loc("role.support.detail")
        case .accelerator:
            loc("role.accelerator.detail")
        }
    }
}

/// H3 ships as two task-specific checkpoints.
enum ModelTask: String, Codable, Sendable, CaseIterable, Identifiable {
    case fl2va = "FL2VA"
    case ref2va = "Ref2VA"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fl2va: loc("task.fl2va")
        case .ref2va: loc("task.ref2va")
        }
    }

    var detail: String {
        switch self {
        case .fl2va:
            loc("task.fl2va.detail")
        case .ref2va:
            loc("task.ref2va.detail")
        }
    }

    var supportedModes: [GenerationMode] {
        switch self {
        case .fl2va: [.textToVideo, .firstFrame, .firstAndLastFrame]
        case .ref2va: [.reference]
        }
    }
}

enum Quantization: String, Codable, Sendable, CaseIterable, Identifiable, Comparable {
    case bf16, int8ConvRot, q8, q6, q4, nvfp4, gguf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bf16: "bfloat16"
        case .int8ConvRot: "INT8 ConvRot"
        case .q8: "8-bit (MLX)"
        case .q6: "6-bit (MLX)"
        case .q4: "4-bit (MLX)"
        case .nvfp4: "NVFP4"
        case .gguf: "GGUF"
        }
    }

    /// Which engines can load this format.
    ///
    /// Was an MLX-only question when MLX was the only backend. Now that ComfyUI
    /// is a real engine, formats it can read — INT8 ConvRot in particular — are
    /// usable even though MLX cannot touch them.
    func isLoadable(by backend: BackendID) -> Bool {
        switch backend {
        case .mlx:
            // MLX reads its own quantized safetensors, and plain bf16.
            switch self {
            case .q4, .q6, .q8, .bf16: true
            default: false
            }
        case .comfyUI:
            // ComfyUI reads bf16 and its own quantized layouts, but has no
            // loader for MLX's format, and GGUF needs a custom node.
            switch self {
            case .bf16, .int8ConvRot: true
            default: false
            }
        }
    }

    /// Why no engine here can load it, or `nil` if one can.
    var unloadableReason: String? {
        guard !BackendID.allCases.contains(where: { isLoadable(by: $0) }) else { return nil }
        switch self {
        case .nvfp4: return loc("quantization.unloadable.nvfp4")
        case .gguf:  return loc("quantization.unloadable.gguf")
        default:     return loc("quantization.unloadable.other", label)
        }
    }

    private var rank: Int {
        switch self {
        case .bf16: 6
        case .int8ConvRot: 5
        case .q8: 4
        case .q6: 3
        case .q4: 2
        case .gguf: 1
        case .nvfp4: 0
        }
    }

    static func < (lhs: Quantization, rhs: Quantization) -> Bool { lhs.rank < rhs.rank }
}

/// A downloadable Hugging Face repository, or a subset of one.
struct CatalogEntry: Identifiable, Codable, Sendable, Hashable {
    var repoID: String
    var role: ModelRole
    var task: ModelTask?
    var quantization: Quantization
    /// On-disk size, read from the Hugging Face file manifest.
    var approximateBytes: Int64
    /// Resident memory during generation, where the port's authors measured it.
    var approximateResidentBytes: Int64?
    /// Restrict the download to these glob patterns. `nil` fetches the whole repo.
    var allowPatterns: [String]?
    var provenance: Provenance
    /// Translation key for what this entry *is*.
    ///
    /// Written out per entry rather than derived from role and format. Deriving it
    /// gave nine different entries the name "bfloat16" — among them a video VAE
    /// that is actually fp16 and an audio VAE that is fp32, because `quantization`
    /// is a required field and those had been given `.bf16` as filler. A name has
    /// to identify the thing it names.
    var nameKey: String

    /// Translation key for the blurb under the model's name. A key rather than
    /// the text itself because `all` is a `static let`: built once, on first
    /// touch, which would otherwise freeze these in whatever language happened
    /// to be current at that moment.
    var summaryKey: String

    var summary: String { loc(summaryKey) }
    /// For ComfyUI-format weights: the single file to fetch, and the folder it
    /// belongs in under `<models>/comfyui/`. ComfyUI cannot read the MLX tree, so
    /// these are downloaded as plain files rather than into the HF cache.
    var comfyUIFile: ComfyUIFile?
    /// Set when the app knows the entry will not work here, beyond its
    /// quantization. A translation key, for the same reason as `summaryKey`.
    var blockedReasonKey: String?

    var blockedReason: String? { blockedReasonKey.map { loc($0) } }

    var id: String { "\(repoID)#\(role.rawValue)#\(task?.rawValue ?? "-")#\(quantization.rawValue)" }

    struct ComfyUIFile: Codable, Sendable, Hashable {
        /// Where the file belongs under `<models>/comfyui/`.
        var folder: String
        var filename: String
        /// Where the file sits *inside its repository*, when that is not
        /// `folder/filename`.
        ///
        /// The official repository happens to lay its files out in the same
        /// folders ComfyUI wants, so the two coincide there and the app assumed
        /// they always would. A community repository is under no such obligation:
        /// the uncensored encoder sits at its repository's root, and asking for
        /// `text_encoders/…` returned a 404 that surfaced only as an unrelated
        /// warning about unauthenticated requests.
        var repoPath: String?

        /// The path to ask the Hub for.
        var remotePath: String { repoPath ?? "\(folder)/\(filename)" }
    }

    enum Provenance: String, Codable, Sendable {
        case official, portMaintainer, community

        var label: String {
            switch self {
            case .official: loc("provenance.official")
            case .portMaintainer: loc("provenance.port")
            case .community: loc("provenance.community")
            }
        }
    }

    /// The path inside the download that the sidecar is actually handed.
    ///
    /// The MLX pipeline loads a whole task directory — `FL2VA/` supplies the text
    /// encoder, both VAEs, the processor and `model_index.json` together — so the
    /// upstream entries resolve to that folder rather than to the snapshot root.
    var componentSubpath: String? {
        guard repoID == Self.upstreamRepoIDStatic else { return nil }
        switch role {
        case .support:     return "FL2VA"
        case .textEncoder: return "FL2VA/text_encoder"
        case .transformer: return task == .ref2va ? "Ref2VA" : "FL2VA"
        case .accelerator: return nil
        }
    }

    /// A path whose existence proves this entry is present, relative to the
    /// snapshot root. Several entries share a repository, so each needs its own.
    var markerPath: String {
        guard repoID == Self.upstreamRepoIDStatic else {
            return "model.safetensors.index.json"
        }
        switch role {
        case .support:     return "FL2VA/video_vae"
        case .textEncoder: return "FL2VA/text_encoder"
        case .transformer: return task == .ref2va ? "Ref2VA/transformer" : "FL2VA/transformer"
        case .accelerator: return "."
        }
    }

    fileprivate static let upstreamRepoIDStatic = "MiniMaxAI/MiniMax-H3"

    /// Why this cannot be used on this machine, or `nil` if it can.
    ///
    /// Judged against the engine that would load it, not against MLX alone.
    var unusableReason: String? {
        if let blockedReason { return blockedReason }
        guard let reason = quantization.unloadableReason else {
            return quantization.isLoadable(by: backend)
                ? nil
                : "\(quantization.label) needs the \(backend == .mlx ? "ComfyUI" : "MLX") engine."
        }
        return reason
    }

    var isUsableHere: Bool { unusableReason == nil }

    /// Which engine loads this. ComfyUI files are never read by MLX and vice versa.
    var backend: BackendID { comfyUIFile == nil ? .mlx : .comfyUI }
    /// Optional rather than forced: `repoID` is catalog data, and a malformed
    /// entry should hide the link rather than crash the Models screen.
    var huggingFaceURL: URL? { URL(string: "https://huggingface.co/\(repoID)") }

    /// What this entry is, rather than where it comes from.
    ///
    /// Several entries share one repository — the upstream release supplies the
    /// VAEs, the text encoder and the Ref2VA checkpoint as separate subsets — so
    /// a repo id alone identifies nothing. Anywhere entries are listed together,
    /// show this instead.
    var displayName: String { loc(nameKey) }

    /// The part of the repository this entry actually fetches, for a subtitle.
    var scopeDescription: String {
        guard let patterns = allowPatterns, !patterns.isEmpty else {
            return "\(repoID) — whole repository"
        }
        let folders = patterns
            .map { $0.split(separator: "/").dropLast().joined(separator: "/") }
            .filter { !$0.isEmpty }
        let unique = Array(Set(folders)).sorted()
        guard !unique.isEmpty else { return repoID }
        return "\(repoID) — \(unique.joined(separator: ", "))"
    }
}
