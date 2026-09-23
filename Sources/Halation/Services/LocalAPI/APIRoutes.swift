import Foundation

/// What each route answers.
///
/// Every answer is built from the same state the windows read, through the same
/// validation the buttons use. Nothing here computes a second opinion: if the
/// API says a combination will swap, it is because `MemoryRequirementsTable`'s
/// arithmetic says so, and if it refuses a render it is with the message the
/// Compose screen would have shown.
@MainActor
struct APIRoutes {
    let app: AppState
    let server: LocalAPIServer

    // MARK: - Reads

    func health() -> HTTPResponse {
        .json([
            "app": "Halation",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            "writes_enabled": server.allowsWrites,
            "max_queue_depth": server.maxQueueDepth,
            "runtime_ready": app.runtime.phase.isReady,
            "licence_accepted": app.licenceProblem == nil,
            "routes": [
                "GET /v1/health", "GET /v1/machine", "GET /v1/models",
                "GET /v1/library", "GET /v1/library/{id}",
                "GET /v1/jobs", "GET /v1/jobs/{id}",
                "POST /v1/estimate",
                "POST /v1/renders", "POST /v1/jobs/{id}/cancel",
                "POST /v1/library/{id}/reproduce",
            ],
        ])
    }

    /// What this Mac can hold, and which combinations fit in it.
    ///
    /// The most useful thing an agent can be told, because its main way of
    /// failing is asking for something this machine cannot hold — and it has no
    /// way to know that unless somebody says.
    func machine() -> HTTPResponse {
        let installed = MachineProfile.physicalBytes
        let metal = MachineProfile.metalUsableBytes
        return .json([
            "installed_memory_bytes": installed,
            "gpu_usable_bytes": metal as Any,
            "note": "Peaks are measured multiples of the weights: 2.4x on MLX, "
                  + "1.41x on ComfyUI, which stages its models rather than "
                  + "holding them all at once.",
            "combinations": MemoryRequirementsTable.apiRows().map { row in
                [
                    "id": row.id,
                    "label": row.label,
                    "weights_bytes": row.weightBytes,
                    "expected_peak_bytes": Int64(row.peakBytes),
                    "verdict": row.verdict,
                ] as [String: Any]
            },
        ])
    }

    func models() -> HTTPResponse {
        let installed = app.modelStore.installedEntryIDs
        return .json([
            "folder": app.modelStore.rootURL.path(percentEncoded: false),
            "free_bytes": app.modelStore.freeBytes,
            "models": ModelCatalog.all.map { entry in
                [
                    "id": entry.id,
                    "repo": entry.repoID,
                    "role": entry.role.rawValue,
                    "task": entry.task?.rawValue as Any,
                    "quantization": entry.quantization.rawValue,
                    "download_bytes": entry.approximateBytes,
                    "resident_bytes": entry.approximateResidentBytes as Any,
                    "installed": installed.contains(entry.id),
                ] as [String: Any]
            },
        ])
    }

    func library() -> HTTPResponse {
        .json(["items": app.library.items.map(Self.describe(item:))])
    }

    func libraryItem(id: String) -> HTTPResponse {
        guard let uuid = UUID(uuidString: id),
              let item = app.library.items.first(where: { $0.id == uuid })
        else { return .error(404, "no_such_item", "No library item with id \(id).") }
        var payload = Self.describe(item: item)
        payload["spec"] = Self.encode(spec: item.spec)
        return .json(payload)
    }

    func jobs() -> HTTPResponse {
        .json(["jobs": app.engine.jobs.map(Self.describe(job:))])
    }

    func job(id: String) -> HTTPResponse {
        guard let uuid = UUID(uuidString: id),
              let job = app.engine.jobs.first(where: { $0.id == uuid })
        else { return .error(404, "no_such_job", "No job with id \(id).") }
        var payload = Self.describe(job: job)
        payload["spec"] = Self.encode(spec: job.spec)
        // The tail only. A failing render can produce thousands of lines, and a
        // client that wanted all of them can ask again as it goes.
        payload["log"] = Array(app.engine.log(for: uuid).suffix(80))
        return .json(payload)
    }

    /// How long and how much, before committing to anything.
    func estimate(body: Data) -> HTTPResponse {
        let request: RenderRequest
        do { request = try RenderRequest.decode(body) } catch { return Self.badRequest(error) }

        let spec = request.apply(to: app.draft, app: app)
        var problems = spec.validate(installed: app.modelStore.installedEntryIDs)
        // Reported by estimate too, so an agent learns about it before it
        // submits rather than by being refused.
        if let licence = app.licenceProblem { problems.insert(licence, at: 0) }
        let blocking = problems.filter { $0.severity == .blocking }

        var payload: [String: Any] = [
            "engine": spec.resolvedBackend.rawValue,
            "frames": spec.sampling.frameCount,
            "seconds": spec.sampling.effectiveSeconds,
            "generates_at": "\(spec.format.generationSize.width)x\(spec.format.generationSize.height)",
            "blocking": blocking.map(\.message),
            "advisories": problems.filter { $0.severity == .advisory }.map(\.message),
            "can_submit": blocking.isEmpty,
        ]

        if let id = spec.transformerEntryID, let entry = ModelCatalog.entry(id: id) {
            let throughput = RenderThroughput.measured(from: app.library.items,
                                                       backend: spec.resolvedBackend)
            let range = spec.sampling.estimatedDuration(
                quantization: entry.quantization,
                pixels: spec.format.generationSize.pixelCount,
                secondsPerStepMegapixel: throughput ?? RenderThroughput.predicted)
            payload["estimated_seconds"] = ["low": Int(range.lowerBound),
                                            "high": Int(range.upperBound)]
            // Worth distinguishing: one is this Mac's own history, the other an
            // extrapolation from a published figure for a different machine.
            payload["estimate_basis"] = throughput == nil ? "predicted" : "measured_here"
        }
        return .json(payload)
    }

    // MARK: - Writes

    func submit(body: Data, maxQueueDepth: Int) -> HTTPResponse {
        let request: RenderRequest
        do { request = try RenderRequest.decode(body) } catch { return Self.badRequest(error) }

        let spec = request.apply(to: app.draft, app: app)
        return enqueue(spec, maxQueueDepth: maxQueueDepth)
    }

    /// The same clip again, seed and all.
    ///
    /// Worth its own route: the seed and the whole spec are already stored per
    /// item, so this is the difference between a true variation and a fresh
    /// roll of the dice — which is what makes iterating on a result possible.
    func reproduce(id: String, maxQueueDepth: Int) -> HTTPResponse {
        guard let uuid = UUID(uuidString: id),
              let item = app.library.items.first(where: { $0.id == uuid })
        else { return .error(404, "no_such_item", "No library item with id \(id).") }

        var spec = item.spec
        spec.sampling.seed = item.seed ?? spec.sampling.seed
        return enqueue(spec, maxQueueDepth: maxQueueDepth)
    }

    func cancel(id: String) -> HTTPResponse {
        guard let uuid = UUID(uuidString: id),
              let job = app.engine.jobs.first(where: { $0.id == uuid })
        else { return .error(404, "no_such_job", "No job with id \(id).") }
        guard !job.state.isTerminal else {
            return .error(409, "already_finished",
                          "That job has already finished (\(job.state.rawValue)).")
        }
        app.engine.cancel(uuid)
        return .json(["id": id, "state": "cancelling"])
    }

    // MARK: - Shared

    private func enqueue(_ spec: GenerationSpec, maxQueueDepth: Int) -> HTTPResponse {
        // Before anything else. The terms cannot be accepted over the API —
        // agreeing to a licence is not something a program should be able to do
        // on a person's behalf — so this is a wall, not a validation failure.
        guard app.licenceProblem == nil else {
            return .error(403, "licence_not_accepted",
                          "The model licence has not been accepted on this Mac. "
                          + "Open Halation, go to Compose, and use \"Review "
                          + "licence\" under \"Before you generate\". Nothing can "
                          + "be rendered until then.")
        }

        let waiting = app.engine.jobs.count { !$0.state.isTerminal }
        guard waiting < maxQueueDepth else {
            return .error(429, "queue_full",
                          "\(waiting) job(s) already waiting, and the limit is "
                          + "\(maxQueueDepth). This machine renders one at a time.")
        }

        let problems = spec.validate(installed: app.modelStore.installedEntryIDs)
        let blocking = problems.filter { $0.severity == .blocking }
        guard blocking.isEmpty else {
            return .json(["error": "invalid_spec",
                          "message": "This render cannot start.",
                          "blocking": blocking.map(\.message)], status: 422)
        }

        let job = app.engine.enqueue(spec)
        InteractionLog.shared.record(.click, "api.submit",
                                     value: spec.resolvedBackend.rawValue, screen: "api")
        var payload = Self.describe(job: job)
        payload["queued_behind"] = waiting
        return .json(payload, status: 201)
    }

    private static func badRequest(_ error: Error) -> HTTPResponse {
        .error(400, "bad_request", error.localizedDescription)
    }

    // MARK: - Shapes

    /// Snake case throughout, ISO dates, bytes as bytes. Chosen for the reader:
    /// these are consumed by something writing a query, not by a person.
    private static func describe(item: LibraryItem) -> [String: Any] {
        [
            "id": item.id.uuidString,
            "title": item.title,
            "prompt": item.spec.prompt,
            "path": item.videoURL.path(percentEncoded: false),
            "exists": item.exists,
            "created_at": ISO8601DateFormatter().string(from: item.createdAt),
            "seed": item.seed as Any,
            "render_seconds": item.renderSeconds as Any,
            "file_size_bytes": item.fileSizeBytes as Any,
            "engine": item.spec.resolvedBackend.rawValue,
            "mode": item.spec.mode.rawValue,
        ]
    }

    private static func describe(job: RenderJob) -> [String: Any] {
        [
            "id": job.id.uuidString,
            "state": job.state.rawValue,
            "prompt": job.spec.prompt,
            "engine": job.spec.resolvedBackend.rawValue,
            "progress": job.progress,
            "completed_steps": job.completedSteps,
            "total_steps": job.totalSteps,
            "created_at": ISO8601DateFormatter().string(from: job.createdAt),
            "started_at": job.startedAt.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "finished_at": job.finishedAt.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "seconds_per_step": job.secondsPerStep as Any,
            "peak_memory_bytes": job.peakMemoryBytes as Any,
            "output_path": job.outputURL?.path(percentEncoded: false) as Any,
            "failure": job.failureMessage as Any,
            "seed": job.resolvedSeed as Any,
        ]
    }

    private static func encode(spec: GenerationSpec) -> Any {
        guard let data = try? JSONEncoder().encode(spec),
              let object = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        return object
    }
}
