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
        case .transformer: "Diffusion transformer"
        case .textEncoder: "Text encoder"
        case .support: "VAEs & processors"
        case .accelerator: "Acceleration LoRAs"
        }
    }

    var detail: String {
        switch self {
        case .transformer:
            "The model itself. Pick one quantization; higher precision costs disk, memory and time."
        case .textEncoder:
            "H3 conditions on Qwen3-VL-32B. This is the largest single download and is shared by both tasks."
        case .support:
            "Small, mandatory, and shared by everything. Install once."
        case .accelerator:
            "Optional LoRAs trained to produce usable video in around 4 steps instead of 50."
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
        case .fl2va: "FL2VA — text & keyframes"
        case .ref2va: "Ref2VA — references"
        }
    }

    var detail: String {
        switch self {
        case .fl2va:
            "Text-to-video, plus optional first and/or last frame images. Use this for most work."
        case .ref2va:
            "Conditions on up to 9 reference images, 3 reference videos and 3 reference audio clips."
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

    /// Whether the MLX pipeline this app drives can load the format at all.
    ///
    /// MLX reads its own quantized safetensors and plain bf16. NVFP4 is a Blackwell
    /// CUDA format, GGUF belongs to llama.cpp/ComfyUI loaders, and INT8 ConvRot is a
    /// PyTorch-side scheme with no Metal kernel — none of them have an MLX path.
    var mlxSupport: Support {
        switch self {
        case .q4, .q6, .q8: .native
        case .bf16: .native
        case .int8ConvRot: .unsupported("INT8 ConvRot is a PyTorch scheme with no Metal kernel.")
        case .nvfp4: .unsupported("NVFP4 is an NVIDIA Blackwell format. There is no Metal path.")
        case .gguf: .unsupported("GGUF is loaded by ComfyUI and llama.cpp, not by the MLX port.")
        }
    }

    enum Support: Sendable, Hashable {
        case native
        case unsupported(String)

        var isUsable: Bool { self == .native }
        var reason: String? { if case .unsupported(let why) = self { why } else { nil } }
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
    var summary: String
    /// Set when the app knows the entry will not work here, beyond its quantization.
    var blockedReason: String?

    var id: String { "\(repoID)#\(role.rawValue)#\(task?.rawValue ?? "-")#\(quantization.rawValue)" }

    enum Provenance: String, Codable, Sendable {
        case official, portMaintainer, community

        var label: String {
            switch self {
            case .official: "Official"
            case .portMaintainer: "MLX port"
            case .community: "Community"
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
    var unusableReason: String? {
        blockedReason ?? quantization.mlxSupport.reason
    }

    var isUsableHere: Bool { unusableReason == nil }
    /// Optional rather than forced: `repoID` is catalog data, and a malformed
    /// entry should hide the link rather than crash the Models screen.
    var huggingFaceURL: URL? { URL(string: "https://huggingface.co/\(repoID)") }

    /// What this entry is, rather than where it comes from.
    ///
    /// Several entries share one repository — the upstream release supplies the
    /// VAEs, the text encoder and the Ref2VA checkpoint as separate subsets — so
    /// a repo id alone identifies nothing. Anywhere entries are listed together,
    /// show this instead.
    var displayName: String {
        switch role {
        case .transformer:
            let task = task.map { " (\($0.rawValue))" } ?? ""
            return "\(quantization.label) transformer\(task)"
        case .textEncoder:
            return "Text encoder — \(quantization.label)"
        case .support:
            return "VAEs, processor & tokenizer"
        case .accelerator:
            return "Acceleration LoRA"
        }
    }

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
