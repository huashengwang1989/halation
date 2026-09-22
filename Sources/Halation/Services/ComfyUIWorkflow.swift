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
    /// Filenames already staged in ComfyUI's input directory, in prompt order.
    /// For keyframe modes these are the first and (optionally) last frame.
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

        nodes.merge(conditioningNodes()) { current, _ in current }

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
        // Ask ComfyUI for the codec directly, so the file is written once in the
        // requested format rather than re-encoded afterwards. SaveVideo supports
        // h264 and av1; anything else would have to be a resample on our side.
        nodes[Node.save] = node("SaveVideo", [
            "video": [Node.createVideo, 0],
            "filename_prefix": outputPrefix,
            "format": "mp4",
            "codec": spec.format.codec.comfyUIName,
        ])
        return nodes
    }

    /// The conditioning node and the images it loads.
    ///
    /// Split out because it is the only part of the graph that varies by mode —
    /// and because both variants emit (CONDITIONING, LATENT), nothing downstream
    /// has to care which was used.
    private func conditioningNodes() -> [String: Any] {
        var nodes: [String: Any] = [:]
        // Every mode shares this graph; only the conditioning node differs, and
        // both produce (CONDITIONING, LATENT) so nothing downstream changes.
        var conditioning: [String: Any] = [
            "clip": [Node.clip, 0],
            "vae": [Node.videoVAE, 0],
            "prompt": spec.prompt,
            "width": spec.format.generationSize.width,
            "height": spec.format.generationSize.height,
            "length": spec.sampling.frameCount,
        ]

        for (index, filename) in referenceImages.enumerated() {
            nodes[Node.image(index)] = node("LoadImage", ["image": filename])
        }

        switch spec.mode {
        case .reference:
            // Ref2VA also conditions the text encoder on audio, so it takes the
            // audio VAE; the keyframe node does not.
            conditioning["audio_vae"] = [Node.audioVAE, 0]
            // "max" uses a 2048px short edge for identity fidelity and is several
            // times slower, because reference tokens ride through every step.
            conditioning["ref_image_size"] = "match"
            for index in referenceImages.indices {
                // Dotted, zero-based autogrow key. The prompt addresses the same
                // reference one-based, as <Picture 1>.
                conditioning["ref_images.ref_image_\(index)"] = [Node.image(index), 0]
            }
            nodes[Node.conditioning] = node("MiniMaxH3ReferenceToVideo", conditioning)

        case .textToVideo, .firstFrame, .firstAndLastFrame:
            // first_frame and last_frame are both optional, so text-to-video is
            // simply this node with neither supplied.
            if referenceImages.indices.contains(0) {
                conditioning["first_frame"] = [Node.image(0), 0]
            }
            if referenceImages.indices.contains(1) {
                conditioning["last_frame"] = [Node.image(1), 0]
            }
            nodes[Node.conditioning] = node("MiniMaxH3ImageToVideo", conditioning)
        }

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

    /// What to write in the log when the graph reaches a node.
    ///
    /// Only the nodes `stage(forNode:)` does *not* recognise ever get here —
    /// the others become a stage change instead and never reach this function.
    /// In practice that means the four setup nodes and the reference images,
    /// and until they were given names the log simply printed their ids: bare
    /// lines reading "41", "42", "40", "43" with nothing to say what they were.
    ///
    /// The rest are still named, because a label function that is total cannot
    /// surprise anyone later if the stage map changes.
    static func nodeLabel(_ id: String) -> String {
        switch id {
        case Node.unet: return "Loading the transformer"
        case Node.lora: return "Loading the turbo LoRA"
        case Node.clip: return "Loading the text encoder"
        case Node.videoVAE: return "Loading the video VAE"
        case Node.audioVAE: return "Loading the audio VAE"
        case Node.conditioning: return "Encoding the prompt and references"
        // The four that actually show up, in the order ComfyUI runs them.
        case Node.guider: return "Setting up guidance"
        case Node.samplerSelect: return "Choosing the sampler"
        case Node.scheduler: return "Building the noise schedule"
        case Node.noise: return "Seeding the noise"
        case Node.sampler: return "Sampling"
        case Node.decodeVideo: return "Decoding the video"
        case Node.decodeAudio: return "Decoding the audio"
        case Node.createVideo, Node.save: return "Writing the file"
        default:
            if (0...9).map(Node.image).contains(id) { return "Loading a reference image" }
            // Self-describing rather than a bare number, so a node this does
            // not know about still reads as something rather than as noise.
            return "Running graph node \(id)"
        }
    }
}
