import Foundation

private let GB: Int64 = 1_073_741_824

/// The curated set of repositories the app knows how to install and wire up.
///
/// Sizes come from each repository's Hugging Face file manifest. The download layer
/// re-reads the manifest before transferring, so these are only used for the
/// pre-flight disk check and the size shown in the UI.

/// The curated set of repositories the app knows how to install and wire up.
///
/// Separated from the type definitions so this file is purely data: adding or
/// correcting an entry never means scrolling past the model that describes it.
///
/// Sizes come from each repository's Hugging Face file manifest. The download
/// layer re-reads the manifest before transferring, so these are used only for
/// the pre-flight disk check and the size shown in the UI.
enum ModelCatalog {
    /// Comfy-Org's repackaged single-file weights, in ComfyUI's own layout.
    static let comfyRepoID = "Comfy-Org/MiniMax-H3"

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

        // ── ComfyUI-format weights ───────────────────────────────────────────
        // Repackaged single files from Comfy-Org. ComfyUI cannot read the MLX
        // tree, so these are a separate download even though the model is the
        // same. INT8 ConvRot is chosen for size: ComfyUI reports no native
        // quantized ops on Metal and emulates them all, so it saves ~40 GB of
        // disk rather than any time.
        CatalogEntry(
            repoID: comfyRepoID,
            role: .transformer,
            task: .ref2va,
            quantization: .int8ConvRot,
            approximateBytes: 21 * GB,
            approximateResidentBytes: 20 * GB,
            allowPatterns: nil,
            provenance: .official,
            summary: "Ref2VA transformer for ComfyUI. Required for reference mode, "
                   + "which the MLX port cannot do at all.",
            comfyUIFile: .init(folder: "diffusion_models",
                               filename: "minimax_h3_ref2va_pruned_int8_convrot.safetensors")
        ),
        CatalogEntry(
            repoID: comfyRepoID,
            role: .transformer,
            task: .fl2va,
            quantization: .int8ConvRot,
            approximateBytes: 21 * GB,
            approximateResidentBytes: 20 * GB,
            allowPatterns: nil,
            provenance: .official,
            summary: "FL2VA transformer for ComfyUI. Only needed if you want to run "
                   + "text-to-video or keyframes through ComfyUI instead of MLX.",
            comfyUIFile: .init(folder: "diffusion_models",
                               filename: "minimax_h3_fl2va_pruned_int8_convrot.safetensors")
        ),
        CatalogEntry(
            repoID: comfyRepoID,
            role: .textEncoder,
            task: nil,
            quantization: .int8ConvRot,
            approximateBytes: 28 * GB,
            approximateResidentBytes: 26 * GB,
            allowPatterns: nil,
            provenance: .official,
            summary: "Qwen3-VL-32B for ComfyUI. Shared by both tasks — download once.",
            comfyUIFile: .init(folder: "text_encoders",
                               filename: "qwen3vl_32b_minimax_h3_int8_convrot.safetensors")
        ),
        CatalogEntry(
            repoID: comfyRepoID,
            role: .support,
            task: nil,
            quantization: .bf16,
            approximateBytes: 6 * GB,
            approximateResidentBytes: 6 * GB,
            allowPatterns: nil,
            provenance: .official,
            summary: "Video VAE in fp16. Chosen over the INT8 build: it is small, and "
                   + "decode quality is visible.",
            comfyUIFile: .init(folder: "vae",
                               filename: "minimax_h3_video_vae_fp16.safetensors")
        ),
        CatalogEntry(
            repoID: comfyRepoID,
            role: .support,
            task: .ref2va,
            quantization: .bf16,
            approximateBytes: 1 * GB,
            approximateResidentBytes: 1 * GB,
            allowPatterns: nil,
            provenance: .official,
            summary: "Audio VAE in fp32, for the stereo track H3 generates alongside "
                   + "the picture.",
            comfyUIFile: .init(folder: "vae",
                               filename: "minimax_h3_audio_vae_fp32.safetensors")
        ),
        CatalogEntry(
            repoID: comfyRepoID,
            role: .accelerator,
            task: .ref2va,
            quantization: .bf16,
            approximateBytes: 2 * GB,
            approximateResidentBytes: 2 * GB,
            allowPatterns: nil,
            provenance: .community,
            summary: "4-step Ref2VA turbo LoRA. This is what makes reference renders "
                   + "practical: about 25 minutes rather than hours.",
            comfyUIFile: .init(folder: "loras",
                               filename: "minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors")
        ),
        CatalogEntry(
            repoID: comfyRepoID,
            role: .accelerator,
            task: .fl2va,
            quantization: .bf16,
            approximateBytes: 2 * GB,
            approximateResidentBytes: 2 * GB,
            allowPatterns: nil,
            provenance: .community,
            summary: "4-step FL2VA turbo LoRA. Distilled for four steps, where MLX's "
                   + "undistilled weights want sixteen.",
            comfyUIFile: .init(folder: "loras",
                               filename: "minimax_h3_fl2v_turbo_4step_v1.2_768p_comfyui_bf16.safetensors")
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
