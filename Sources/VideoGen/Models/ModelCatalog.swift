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
    var huggingFaceURL: URL { URL(string: "https://huggingface.co/\(repoID)")! }
}

private let GB: Int64 = 1_073_741_824

/// The curated set of repositories the app knows how to install and wire up.
///
/// Sizes come from each repository's Hugging Face file manifest. The download layer
/// re-reads the manifest before transferring, so these are only used for the
/// pre-flight disk check and the size shown in the UI.
enum ModelCatalog {
    static let upstreamRepoID = "MiniMaxAI/MiniMax-H3"

    /// The upstream repo publishes its components twice: once at the top level in
    /// diffusers layout, and once mirrored inside `FL2VA/` and `Ref2VA/`. We always
    /// take the top-level copies — fetching a task folder would pull a second
    /// 66 GB copy of the same text encoder.
    static let all: [CatalogEntry] = [
        // ── Mandatory shared components ──────────────────────────────────────
        CatalogEntry(
            repoID: upstreamRepoID,
            role: .support,
            task: nil,
            quantization: .bf16,
            approximateBytes: 12 * GB,
            approximateResidentBytes: 4 * GB,
            allowPatterns: ["FL2VA/model_index.json", "FL2VA/video_vae/*",
                            "FL2VA/audio_vae/*", "FL2VA/processor/*", "FL2VA/tokenizer/*"],
            provenance: .official,
            summary: "Video VAE (10.4 GB), audio VAE, processor and tokenizer, taken from the "
                   + "FL2VA task directory the pipeline loads as a unit. Required by every run."
        ),
        CatalogEntry(
            repoID: upstreamRepoID,
            role: .textEncoder,
            task: nil,
            quantization: .bf16,
            approximateBytes: 67 * GB,
            approximateResidentBytes: 34 * GB,
            allowPatterns: ["FL2VA/text_encoder/*"],
            provenance: .official,
            summary: "Qwen3-VL-32B in bfloat16 — H3 reads its 50th-layer hidden states. "
                   + "The largest single download, and currently the only text encoder the "
                   + "MLX pipeline can load. It installs beside the VAEs in FL2VA/."
        ),

        // ── MLX diffusion transformers (FL2VA) ───────────────────────────────
        // The MLX builds are transformer-only and flat: the VAEs and encoder come
        // from the upstream release above.
        CatalogEntry(
            repoID: "pipenetwork/MiniMax-H3-MLX-4bit",
            role: .transformer,
            task: .fl2va,
            quantization: .q4,
            approximateBytes: 26 * GB,
            approximateResidentBytes: 12 * GB,
            allowPatterns: nil,
            provenance: .portMaintainer,
            summary: "4-bit, group size 64. Around 1.4× faster than bf16 and only ~12 GB "
                   + "resident. Loses some fine texture. The best place to start."
        ),
        CatalogEntry(
            repoID: "pipenetwork/MiniMax-H3-MLX-6bit",
            role: .transformer,
            task: .fl2va,
            quantization: .q6,
            approximateBytes: 31 * GB,
            approximateResidentBytes: 17 * GB,
            allowPatterns: nil,
            provenance: .portMaintainer,
            summary: "6-bit. A middle point if 4-bit looks soft and 8-bit is too slow."
        ),
        CatalogEntry(
            repoID: "pipenetwork/MiniMax-H3-MLX-8bit",
            role: .transformer,
            task: .fl2va,
            quantization: .q8,
            approximateBytes: 36 * GB,
            approximateResidentBytes: 22 * GB,
            allowPatterns: nil,
            provenance: .portMaintainer,
            summary: "The quality-per-gigabyte sweet spot — visually very close to bf16."
        ),
        CatalogEntry(
            repoID: "pipenetwork/MiniMax-H3-MLX-bf16",
            role: .transformer,
            task: .fl2va,
            quantization: .bf16,
            approximateBytes: 67 * GB,
            approximateResidentBytes: 41 * GB,
            allowPatterns: nil,
            provenance: .portMaintainer,
            summary: "Reference precision, validated against the diffusers implementation. "
                   + "Slowest, and alongside the 67 GB encoder it leaves little headroom "
                   + "even in 128 GB."
        ),

        // ── Ref2VA ───────────────────────────────────────────────────────────
        // No MLX conversion of the Ref2VA transformer has been published, so this is
        // the upstream bf16 checkpoint. Whether the port can drive it depends on the
        // version installed; the app probes for that at launch.
        CatalogEntry(
            repoID: upstreamRepoID,
            role: .transformer,
            task: .ref2va,
            quantization: .bf16,
            approximateBytes: 67 * GB,
            approximateResidentBytes: 41 * GB,
            allowPatterns: ["Ref2VA/*"],
            provenance: .official,
            summary: "Upstream bf16 Ref2VA checkpoint. Listed so the option is visible, but "
                   + "the MLX port's pipeline accepts keyframes only — it has no reference "
                   + "conditioning path — so this cannot be driven from this app yet.",
            blockedReason: "The MLX port does not implement reference conditioning. Ref2VA "
                         + "currently needs the CUDA stack (SGLang, vLLM or ComfyUI)."
        ),

        // ── Acceleration ─────────────────────────────────────────────────────
        CatalogEntry(
            repoID: "lightx2v/Minimax-h3-Turbo",
            role: .accelerator,
            task: .fl2va,
            quantization: .bf16,
            approximateBytes: 2 * GB,
            approximateResidentBytes: 2 * GB,
            allowPatterns: ["*turbo_4step_v1.2_768p_bf16.safetensors", "*.json", "*.md"],
            provenance: .community,
            summary: "A 4-step distillation LoRA for FL2VA at 768p — the single biggest "
                   + "speed win available for this model. The MLX port has no LoRA loader "
                   + "yet, so it is listed here to watch rather than to install.",
            blockedReason: "The MLX port has no LoRA loader yet. Fusing this would need a "
                         + "merged checkpoint rather than the LoRA on its own."
        ),

        // ── Listed but not usable here ───────────────────────────────────────
        CatalogEntry(
            repoID: "linjian257/qwen3vl_32b_minimax_h3_int8_convrot_uncensored-by-linjian257",
            role: .textEncoder,
            task: nil,
            quantization: .int8ConvRot,
            approximateBytes: 26 * GB,
            approximateResidentBytes: nil,
            allowPatterns: nil,
            provenance: .community,
            summary: "A community text encoder with the refusal behaviour trained out, in "
                   + "INT8 ConvRot. It targets the PyTorch/ComfyUI path; the MLX pipeline "
                   + "cannot load this format, so it is listed for reference only."
        ),
        CatalogEntry(
            repoID: "unsloth/MiniMax-H3-GGUF",
            role: .transformer,
            task: .fl2va,
            quantization: .gguf,
            approximateBytes: 20 * GB,
            approximateResidentBytes: nil,
            allowPatterns: nil,
            provenance: .community,
            summary: "GGUF quantizations, including very small ones. Loaded by ComfyUI, "
                   + "not by MLX — useful if you ever run this model through ComfyUI instead."
        ),
        CatalogEntry(
            repoID: "coolthor/MiniMax-H3-pruned-NVFP4",
            role: .transformer,
            task: .fl2va,
            quantization: .nvfp4,
            approximateBytes: 15 * GB,
            approximateResidentBytes: nil,
            allowPatterns: nil,
            provenance: .community,
            summary: "Community prune in NVIDIA's NVFP4 format. Listed for completeness."
        )
    ]

    static func entries(role: ModelRole) -> [CatalogEntry] {
        all.filter { $0.role == role }
    }

    static func transformers(task: ModelTask) -> [CatalogEntry] {
        all.filter { $0.role == .transformer && $0.task == task }
            .sorted { $0.quantization > $1.quantization }
    }

    /// Installed when the user accepts the recommended fast-preview setup:
    /// 4-bit transformer, the bf16 encoder, and the mandatory support files.
    static var recommendedBundle: [CatalogEntry] {
        all.filter {
            $0.role == .support
            || ($0.role == .textEncoder && $0.quantization == .bf16 && $0.provenance == .official)
            || ($0.role == .transformer && $0.task == .fl2va && $0.quantization == .q4)
        }
    }

    static var recommendedBytes: Int64 {
        recommendedBundle.reduce(0) { $0 + $1.approximateBytes }
    }

    static func entry(id: String) -> CatalogEntry? { all.first { $0.id == id } }
}
