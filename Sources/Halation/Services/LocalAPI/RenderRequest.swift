import Foundation

/// What a caller sends to `/v1/estimate` and `/v1/renders`.
///
/// Deliberately not `GenerationSpec`. That type is the app's internal shape —
/// nested settings, catalogue ids, reference assets — and making a caller
/// reproduce it would mean an agent had to know things it has no way to learn,
/// like which text encoder pairs with which transformer. This is the short form:
/// a prompt and whatever else you care to override.
///
/// Everything omitted comes from the draft on the Compose screen, which already
/// holds a working, validated combination. So the smallest useful request is
/// `{"prompt": "..."}` and it renders the way the app is currently set up.
struct RenderRequest: Decodable {
    var prompt: String?
    var engine: String?
    var mode: String?
    var seconds: Int?
    var steps: Int?
    var aspect: String?
    var resolution: String?
    var codec: String?
    /// `off`, `easycache` or `lazycache`. ComfyUI only, and a preview setting:
    /// it buys time with quality.
    var cache: String?
    /// Omit for a fresh roll; give one to reproduce a previous render exactly.
    var seed: Int64?

    static func decode(_ body: Data) throws -> RenderRequest {
        guard !body.isEmpty else { return RenderRequest() }
        do {
            return try JSONDecoder().decode(RenderRequest.self, from: body)
        } catch {
            throw RequestError.malformed
        }
    }

    enum RequestError: LocalizedError {
        case malformed
        var errorDescription: String? {
            #"Could not read the body as JSON. Expected e.g. {"prompt": "a harbour at dusk", "steps": 8}."#
        }
    }

    /// Overlays this request on the app's current draft.
    ///
    /// The draft is the base rather than a blank spec because it carries the
    /// chosen models. A caller that names none still gets a combination the app
    /// has already decided is workable on this machine.
    @MainActor
    func apply(to draft: GenerationSpec, app: AppState) -> GenerationSpec {
        var spec = draft
        if let prompt { spec.prompt = prompt }
        if let mode, let parsed = GenerationMode(rawValue: mode) { spec.mode = parsed }
        if let engine {
            // "auto" is spelled as absence internally, which is not a thing a
            // caller should have to know.
            spec.backend = engine.lowercased() == "auto" ? nil : BackendID(rawValue: engine)
        }
        if let seconds { spec.sampling.durationSeconds = seconds }
        if let steps { spec.sampling.steps = steps }
        if let seed { spec.sampling.seed = seed }
        if let aspect, let parsed = AspectRatio(rawValue: aspect) {
            spec.format.aspectRatio = parsed
        }
        if let resolution, let parsed = ResolutionTier(rawValue: resolution) {
            spec.format.resolution = parsed
        }
        if let codec, let parsed = VideoCodec(rawValue: codec) { spec.format.codec = parsed }
        if let cache, let parsed = StepCache(rawValue: cache.lowercased()) {
            spec.sampling.stepCache = parsed
        }

        // References are not accepted over the API: they are files on disk, and
        // taking a path from a caller would let it read anything the app can.
        // A reference render has to be set up in the app.
        if spec.mode != draft.mode { spec.references = [] }

        // A caller that named no mode inherits the draft's — but every mode
        // except the first needs files the API cannot be given, so inheriting
        // one of those hands back a render that can never start. Found exactly
        // that way: `{"prompt": "..."}` came back "Ref2VA needs at least one
        // reference file", because the app happened to be left in reference
        // mode. Naming a mode still gets you that mode, and still fails if the
        // files are not there — that is the caller's own doing.
        if mode == nil, spec.mode != .textToVideo, spec.references.isEmpty {
            spec.mode = .textToVideo
        }

        // The models the app would pick for this combination, so a caller that
        // switched mode or engine does not end up with a mismatched pair.
        return app.resolvingModels(for: spec)
    }
}
