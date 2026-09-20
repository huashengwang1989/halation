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
    /// Where the turbo LoRAs are distilled and published.
    static let turboRepoID = "lightx2v/Minimax-h3-Turbo"

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
            nameKey: "model.name.support.mlx",
            summaryKey: "model.support.mlx"
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
            nameKey: "model.name.textEncoder.mlx",
            summaryKey: "model.textEncoder.mlx"
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
            nameKey: "model.name.fl2va.q4",
            summaryKey: "model.fl2va.q4"
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
            nameKey: "model.name.fl2va.q6",
            summaryKey: "model.fl2va.q6"
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
            nameKey: "model.name.fl2va.q8",
            summaryKey: "model.fl2va.q8"
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
            nameKey: "model.name.fl2va.bf16",
            summaryKey: "model.fl2va.bf16"
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
            nameKey: "model.name.ref2va.bf16",
            summaryKey: "model.ref2va.bf16",
            blockedReasonKey: "model.ref2va.bf16.blocked"
        ),

        // ── Acceleration ─────────────────────────────────────────────────────
        CatalogEntry(
            repoID: turboRepoID,
            role: .accelerator,
            task: .fl2va,
            quantization: .bf16,
            approximateBytes: 2 * GB,
            approximateResidentBytes: 2 * GB,
            allowPatterns: ["*turbo_4step_v1.2_768p_bf16.safetensors", "*.json", "*.md"],
            provenance: .community,
            nameKey: "model.name.lora.fl2va.mlx",
            summaryKey: "model.lora.fl2va.mlx",
            blockedReasonKey: "model.lora.fl2va.mlx.blocked"
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
            nameKey: "model.name.comfy.ref2va",
            summaryKey: "model.comfy.ref2va",
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
            nameKey: "model.name.comfy.fl2va",
            summaryKey: "model.comfy.fl2va",
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
            nameKey: "model.name.comfy.textEncoder",
            summaryKey: "model.comfy.textEncoder",
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
            nameKey: "model.name.comfy.videoVAE",
            summaryKey: "model.comfy.videoVAE",
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
            nameKey: "model.name.comfy.audioVAE",
            summaryKey: "model.comfy.audioVAE",
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
            nameKey: "model.name.comfy.lora.ref2va",
            summaryKey: "model.comfy.lora.ref2va",
            comfyUIFile: .init(folder: "loras",
                               filename: "minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors")
        ),
        CatalogEntry(
            // The distiller's own repository, not the Comfy-Org mirror. The
            // mirror carries only v1.0 of this LoRA, so asking it for the v1.2
            // the rest of the app expects returned a 404.
            repoID: turboRepoID,
            role: .accelerator,
            task: .fl2va,
            quantization: .bf16,
            approximateBytes: 2 * GB,
            approximateResidentBytes: 2 * GB,
            allowPatterns: nil,
            provenance: .community,
            nameKey: "model.name.comfy.lora.fl2va",
            summaryKey: "model.comfy.lora.fl2va",
            comfyUIFile: .init(folder: "loras",
                               filename: "minimax_h3_fl2v_turbo_4step_v1.2_768p_comfyui_bf16.safetensors",
                               // Flat repository: no folders to mirror.
                               repoPath: "minimax_h3_fl2v_turbo_4step_v1.2_768p_comfyui_bf16.safetensors")
        ),

        // ── Listed but not usable here ───────────────────────────────────────
        CatalogEntry(
            repoID: "linjian257/qwen3vl_32b_minimax_h3_int8_convrot_uncensored-by-linjian257",
            role: .textEncoder,
            task: nil,
            quantization: .int8ConvRot,
            approximateBytes: 26 * GB,
            approximateResidentBytes: 26 * GB,
            allowPatterns: nil,
            provenance: .community,
            nameKey: "model.name.textEncoder.uncensored",
            summaryKey: "model.textEncoder.uncensored",
            comfyUIFile: .init(
                folder: "text_encoders",
                filename: "qwen3vl_32b_minimax_h3_int8_convrot_uncensored-by-linjian257.safetensors",
                // This repository holds the one file at its root, not under a
                // folder mirroring ComfyUI's layout.
                repoPath: "qwen3vl_32b_minimax_h3_int8_convrot_uncensored-by-linjian257.safetensors")
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
            nameKey: "model.name.fl2va.gguf",
            summaryKey: "model.fl2va.gguf"
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
            nameKey: "model.name.fl2va.nvfp4",
            summaryKey: "model.fl2va.nvfp4"
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
