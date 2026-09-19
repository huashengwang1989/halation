import Foundation

/// Builds the ComfyUI prompt graph for a MiniMax H3 render.
///
/// Derived from ComfyUI's own `video_minimax_h3_r2v.json` template and validated
/// by an end-to-end run: 1344×768, 124 frames, 4 steps, 26m47s on Metal.
/// Structure follows that template — `res_multistep` sampler, `simple` scheduler,
/// `SamplerCustomAdvanced` — rather than anything invented here.
///
/// Built in Swift rather than patched from JSON because the reference inputs are
/// dynamic: ComfyUI addresses them by dotted, zero-based keys
/// (`ref_images.ref_image_0`) whose count depends on what the user attached.
struct ComfyUIWorkflow {
    /// The ComfyUI-format filenames this graph loads.
    struct Models: Sendable {
        var transformer: String
        var textEncoder: String
        var videoVAE: String
        var audioVAE: String
        /// Step-reduction LoRA. Omitting it means the full step count.
        var turboLoRA: String?
    }

    var spec: GenerationSpec
    var models: Models
    var seed: Int64
    /// Filenames already uploaded into ComfyUI's input directory, in prompt order.
    var referenceImages: [String]
    var outputPrefix: String

    /// Node ids. Stable so progress events can be attributed to a stage.
    enum Node {
        static let unet = "10", lora = "11", clip = "12"
        static let videoVAE = "13", audioVAE = "14"
        static let conditioning = "30", guider = "40", samplerSelect = "41"
        static let scheduler = "42", noise = "43", sampler = "44"
        static let decodeVideo = "50", decodeAudio = "51"
        static let createVideo = "60", save = "70"
        static func image(_ index: Int) -> String { "2\(index)" }
    }

    func graph() -> [String: Any] {
        var nodes: [String: Any] = [:]

        nodes[Node.unet] = node("UNETLoader", [
            "unet_name": models.transformer,
            "weight_dtype": "default",
        ])

        // The LoRA is model-only; conditioning comes from the H3 node.
        let modelSource: [Any]
        if let lora = models.turboLoRA {
            nodes[Node.lora] = node("LoraLoaderModelOnly", [
                "model": [Node.unet, 0],
                "lora_name": lora,
                "strength_model": 1.0,
            ])
            modelSource = [Node.lora, 0]
        } else {
            modelSource = [Node.unet, 0]
        }

        nodes[Node.clip] = node("CLIPLoader", [
            "clip_name": models.textEncoder,
            "type": "minimax",
            "device": "default",
        ])
        nodes[Node.videoVAE] = node("VAELoader", ["vae_name": models.videoVAE])
        nodes[Node.audioVAE] = node("VAELoader", ["vae_name": models.audioVAE])

        var conditioning: [String: Any] = [
            "clip": [Node.clip, 0],
            "vae": [Node.videoVAE, 0],
            "audio_vae": [Node.audioVAE, 0],
            "prompt": spec.prompt,
            "width": spec.format.generationSize.width,
            "height": spec.format.generationSize.height,
            "length": spec.sampling.frameCount,
            // "max" uses a 2048px short edge for identity fidelity and is several
            // times slower, because reference tokens ride through every step.
            "ref_image_size": "match",
        ]

        for (index, filename) in referenceImages.enumerated() {
            nodes[Node.image(index)] = node("LoadImage", ["image": filename])
            // Dotted, zero-based autogrow key. The prompt addresses the same
            // reference one-based, as <Picture 1>.
            conditioning["ref_images.ref_image_\(index)"] = [Node.image(index), 0]
        }
        nodes[Node.conditioning] = node("MiniMaxH3ReferenceToVideo", conditioning)

        nodes[Node.guider] = node("BasicGuider", [
            "model": modelSource,
            "conditioning": [Node.conditioning, 0],
        ])
        nodes[Node.samplerSelect] = node("KSamplerSelect", ["sampler_name": "res_multistep"])
        nodes[Node.scheduler] = node("BasicScheduler", [
            "model": modelSource,
            "scheduler": "simple",
            "steps": spec.sampling.steps,
            "denoise": 1.0,
        ])
        nodes[Node.noise] = node("RandomNoise", ["noise_seed": Int(truncatingIfNeeded: seed)])
        nodes[Node.sampler] = node("SamplerCustomAdvanced", [
            "noise": [Node.noise, 0],
            "guider": [Node.guider, 0],
            "sampler": [Node.samplerSelect, 0],
            "sigmas": [Node.scheduler, 0],
            // Output 1 of the H3 node is the joint audio/video latent.
            "latent_image": [Node.conditioning, 1],
        ])

        nodes[Node.decodeVideo] = node("VAEDecode", [
            "samples": [Node.sampler, 0], "vae": [Node.videoVAE, 0],
        ])
        nodes[Node.decodeAudio] = node("VAEDecodeAudio", [
            "samples": [Node.sampler, 0], "vae": [Node.audioVAE, 0],
        ])
        nodes[Node.createVideo] = node("CreateVideo", [
            "images": [Node.decodeVideo, 0],
            "fps": Double(FrameGrid.fps),
            "audio": [Node.decodeAudio, 0],
        ])
        nodes[Node.save] = node("SaveVideo", [
            "video": [Node.createVideo, 0],
            "filename_prefix": outputPrefix,
            "format": "auto",
            "codec": "auto",
        ])
        return nodes
    }

    private func node(_ classType: String, _ inputs: [String: Any]) -> [String: Any] {
        ["class_type": classType, "inputs": inputs]
    }

    /// Which stage a node id belongs to, so progress can be labelled.
    static func stage(forNode id: String) -> RenderJob.State? {
        switch id {
        case Node.unet, Node.lora, Node.clip, Node.videoVAE, Node.audioVAE: .preparing
        case Node.conditioning, Node.sampler: .generating
        case Node.decodeVideo, Node.decodeAudio: .decoding
        case Node.createVideo, Node.save: .encoding
        default: nil
        }
    }

    static func nodeLabel(_ id: String) -> String {
        switch id {
        case Node.unet: "transformer"
        case Node.lora: "turbo LoRA"
        case Node.clip: "text encoder"
        case Node.videoVAE: "video VAE"
        case Node.audioVAE: "audio VAE"
        case Node.conditioning: "encoding prompt and references"
        case Node.sampler: "sampling"
        case Node.decodeVideo: "decoding video"
        case Node.decodeAudio: "decoding audio"
        case Node.createVideo, Node.save: "writing file"
        default: id
        }
    }
}
