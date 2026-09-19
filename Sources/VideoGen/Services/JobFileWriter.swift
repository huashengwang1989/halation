import Foundation

/// Writes the flat JSON the MLX sidecar consumes, resolving every catalog
/// reference to a real path on disk.
///
/// Lives outside `RenderEngine` so the backend that actually needs it owns it.
@MainActor
struct JobFileWriter {
    let modelStore: ModelStore

    /// Serialises the spec into the flat shape the sidecar expects, resolving every
    /// catalog reference to a real path on disk.
    func write(spec: GenerationSpec, rawOutput: URL, to url: URL) throws {
        var payload: [String: Any] = [
            "prompt": spec.prompt,
            "duration_seconds": spec.sampling.durationSeconds,
            "aspect_width": spec.format.aspectRatio.aspectPair.width,
            "aspect_height": spec.format.aspectRatio.aspectPair.height,
            "steps": spec.sampling.steps,
            "width": spec.format.generationSize.width,
            "height": spec.format.generationSize.height,
            "raw_output_path": rawOutput.path,
            "mode": spec.mode.rawValue,
            "task": spec.task.rawValue,
        ]
        if let seed = spec.sampling.seed { payload["seed"] = seed }

        // `localPath` already resolves to the component folder when the repository
        // holds more than one, so these are handed over as-is.
        if let id = spec.transformerEntryID, let entry = ModelCatalog.entry(id: id),
           let path = modelStore.localPath(for: entry) {
            payload["transformer_path"] = path.path
        }
        if let id = spec.textEncoderEntryID, let entry = ModelCatalog.entry(id: id),
           let path = modelStore.localPath(for: entry) {
            payload["text_encoder_path"] = path.path
        }
        if let support = ModelCatalog.entries(role: .support).first,
           let path = modelStore.localPath(for: support) {
            payload["support_path"] = path.path
        }

        // Conditioning inputs, in the order the model consumes them.
        for asset in spec.references {
            switch (asset.kind, asset.slot) {
            case (.image, .first): payload["first_frame"] = asset.url.path
            case (.image, .last):  payload["last_frame"] = asset.url.path
            case (.image, .reference):
                var list = payload["reference_images"] as? [String] ?? []
                list.append(asset.url.path)
                payload["reference_images"] = list
            case (.video, _):
                var list = payload["reference_videos"] as? [String] ?? []
                list.append(asset.url.path)
                payload["reference_videos"] = list
            case (.audio, _):
                var list = payload["reference_audios"] as? [String] ?? []
                list.append(asset.url.path)
                payload["reference_audios"] = list
            }
        }

        let data = try JSONSerialization.data(withJSONObject: payload,
                                              options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}
