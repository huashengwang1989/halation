import Foundation

/// The ComfyUI-format weights a render needs, and where they live.
///
/// ComfyUI cannot use the MLX weights: it wants repackaged single-file
/// safetensors from `Comfy-Org/MiniMax-H3` in a flat layout. They still live in
/// the shared models folder, under `comfyui/`, so everything is in one place.
enum ComfyUIModelSet {
    /// Filenames as published by `Comfy-Org/MiniMax-H3`.
    ///
    /// INT8 ConvRot is chosen for size, not speed: ComfyUI reports *no* native
    /// quantized ops on Metal and emulates them all, so INT8 saves ~40 GB of disk
    /// and costs some throughput.
    static func transformer(for task: ModelTask) -> String {
        switch task {
        case .ref2va: "minimax_h3_ref2va_pruned_int8_convrot.safetensors"
        case .fl2va:  "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
        }
    }

    static func turboLoRA(for task: ModelTask) -> String {
        switch task {
        case .ref2va: "minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"
        case .fl2va:  "minimax_h3_fl2v_turbo_4step_v1.2_768p_comfyui_bf16.safetensors"
        }
    }

    static let textEncoder = "qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
    static let videoVAE = "minimax_h3_video_vae_fp16.safetensors"
    static let audioVAE = "minimax_h3_audio_vae_fp32.safetensors"

    /// Folder each file belongs in, relative to the ComfyUI models root.
    static func folder(for filename: String) -> String {
        if filename.contains("vae") { return "vae" }
        if filename.contains("qwen3vl") { return "text_encoders" }
        if filename.contains("turbo") { return "loras" }
        return "diffusion_models"
    }

    /// Everything required for a task, as (folder, filename) pairs.
    static func required(for task: ModelTask) -> [(folder: String, file: String)] {
        [transformer(for: task), textEncoder, videoVAE, audioVAE]
            .map { (folder(for: $0), $0) }
    }

    /// Files that are required but absent. `modelsRoot` is the shared folder.
    static func missing(in modelsRoot: URL, for task: ModelTask) -> [String] {
        let root = modelsRoot.appending(path: "comfyui", directoryHint: .isDirectory)
        return required(for: task)
            .filter { !FileManager.default.fileExists(
                atPath: root.appending(path: "\($0.folder)/\($0.file)").path) }
            .map(\.file)
    }

    /// Resolves the set for a task, if it is fully present. `root` is the shared
    /// models folder; the turbo LoRA is optional and used when found.
    static func resolve(in root: URL, task: ModelTask) -> ComfyUIWorkflow.Models? {
        guard missing(in: root, for: task).isEmpty else { return nil }
        let comfy = root.appending(path: "comfyui", directoryHint: .isDirectory)
        let lora = turboLoRA(for: task)
        let hasLoRA = FileManager.default.fileExists(
            atPath: comfy.appending(path: "loras/\(lora)").path)
        return ComfyUIWorkflow.Models(
            transformer: transformer(for: task),
            textEncoder: textEncoder,
            videoVAE: videoVAE,
            audioVAE: audioVAE,
            turboLoRA: hasLoRA ? lora : nil)
    }

    /// Steps to use. The turbo LoRAs are 4-step distillations; without one the
    /// template's full-quality count applies.
    static func recommendedSteps(hasTurboLoRA: Bool) -> Int { hasTurboLoRA ? 4 : 20 }
}
