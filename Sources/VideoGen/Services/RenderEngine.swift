import Foundation
import Observation

/// Owns the render queue and the sidecar process that serves it.
///
/// One render at a time, always. A 33B transformer plus its text encoder can hold
/// 40 GB resident; two concurrent jobs would swap and take longer than running them
/// back to back.
@MainActor
@Observable
final class RenderEngine {
    private(set) var jobs: [RenderJob] = []
    private(set) var isRunning = false
    /// Tail of the current job's sidecar output, for the log inspector.
    private(set) var currentLog: [String] = []

    /// Set false to let the queue drain without starting anything new.
    var autoStart = true

    private let runtime: RuntimeManager
    private let modelStore: ModelStore
    private let library: LibraryStore

    private var runner: ProcessRunner?
    private var activeTask: Task<Void, Never>?
    private var cancelledJobIDs = Set<UUID>()

    init(runtime: RuntimeManager, modelStore: ModelStore, library: LibraryStore) {
        self.runtime = runtime
        self.modelStore = modelStore
        self.library = library
        jobs = Self.loadQueue()
        // A job that was mid-flight when the app quit cannot be resumed inside the
        // sidecar, so it returns to the queue rather than lying about its state.
        for index in jobs.indices where jobs[index].state.isActive {
            jobs[index].state = .queued
            jobs[index].progress = 0
            jobs[index].completedSteps = 0
        }
    }

    // MARK: - Queue management

    func enqueue(_ spec: GenerationSpec) -> RenderJob {
        let job = RenderJob(spec: spec)
        jobs.append(job)
        persist()
        startNextIfIdle()
        return job
    }

    func cancel(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        if jobs[index].state.isActive {
            cancelledJobIDs.insert(id)
            activeTask?.cancel()
            Task { await runner?.terminate() }
        } else {
            jobs[index].state = .cancelled
            jobs[index].finishedAt = .now
            persist()
        }
    }

    func remove(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        if jobs[index].state.isActive { cancel(id); return }
        jobs.remove(at: index)
        persist()
    }

    func clearFinished() {
        jobs.removeAll { $0.state.isTerminal }
        persist()
    }

    /// Re-queues a failed or finished job with the same spec and a fresh seed.
    func retry(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        var spec = job.spec
        spec.sampling.seed = nil
        _ = enqueue(spec)
    }

    /// Re-runs a job with its exact original seed, reproducing the same clip.
    func reproduce(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        var spec = job.spec
        spec.sampling.seed = job.resolvedSeed ?? spec.sampling.seed
        _ = enqueue(spec)
    }

    func moveToFront(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }),
              jobs[index].state == .queued else { return }
        let job = jobs.remove(at: index)
        let insertAt = jobs.firstIndex { $0.state == .queued } ?? jobs.count
        jobs.insert(job, at: insertAt)
        persist()
    }

    var activeJob: RenderJob? { jobs.first { $0.state.isActive } }
    var queuedCount: Int { jobs.count { $0.state == .queued } }

    // MARK: - Execution

    func startNextIfIdle() {
        guard autoStart, !isRunning, runtime.phase.isReady,
              let next = jobs.first(where: { $0.state == .queued })
        else { return }
        activeTask = Task { await run(jobID: next.id) }
    }

    private func run(jobID: UUID) async {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        isRunning = true
        currentLog.removeAll()
        defer {
            isRunning = false
            persist()
            startNextIfIdle()
        }

        jobs[index].state = .preparing
        jobs[index].startedAt = .now
        jobs[index].progress = 0

        let spec = jobs[index].spec
        let scratch = Self.scratchDirectory.appending(path: jobID.uuidString, directoryHint: .isDirectory)

        // Declared outside the `do` so the `catch` can prefer it. The sidecar
        // reports why it failed as an event *before* exiting non-zero, and the
        // process error that follows is only ever "exited with code 1" — so
        // catching without consulting this threw away the actual reason.
        var sidecarFailure: String?

        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            let rawOutput = scratch.appending(path: "render.mp4")
            let jobFile = scratch.appending(path: "job.json")
            try writeJobFile(spec: spec, rawOutput: rawOutput, to: jobFile)

            let runner = ProcessRunner()
            self.runner = runner

            var rawVideoURL: URL?

            let stream = await runner.lines(.init(
                executable: runtime.pythonURL,
                arguments: [runtime.sidecarScript.path, "generate", "--job", jobFile.path],
                environment: runtime.environment()))

            for try await line in stream {
                guard let event = SidecarEvent.parse(line: line) else { continue }
                guard jobs.contains(where: { $0.id == jobID }) else { break }
                apply(event, to: jobID, video: &rawVideoURL, failure: &sidecarFailure)
            }

            if cancelledJobIDs.contains(jobID) { throw CancellationError() }
            if let sidecarFailure { throw EngineError.sidecar(sidecarFailure) }
            guard let rawVideoURL, FileManager.default.fileExists(atPath: rawVideoURL.path) else {
                throw EngineError.noOutput
            }

            // ── Post-process into the delivery format ────────────────────────
            guard let liveIndex = jobs.firstIndex(where: { $0.id == jobID }) else { return }
            jobs[liveIndex].state = .encoding
            jobs[liveIndex].progress = 0

            let destination = library.destinationURL(for: spec, jobID: jobID)
            let processor = VideoPostProcessor(format: spec.format)
            let result = try await processor.process(source: rawVideoURL, destination: destination)

            guard let finalIndex = jobs.firstIndex(where: { $0.id == jobID }) else { return }
            jobs[finalIndex].outputURL = result.videoURL
            jobs[finalIndex].sidecarAudioURL = result.audioURL
            jobs[finalIndex].thumbnailURL = result.thumbnailURL
            jobs[finalIndex].state = .finished
            jobs[finalIndex].finishedAt = .now
            jobs[finalIndex].progress = 1

            library.record(job: jobs[finalIndex])
            try? FileManager.default.removeItem(at: scratch)

        } catch is CancellationError {
            mark(jobID, state: .cancelled, message: nil)
            cancelledJobIDs.remove(jobID)
            try? FileManager.default.removeItem(at: scratch)
        } catch {
            // A SIGTERM from our own cancel surfaces as a process error, not a
            // CancellationError, so check intent before calling it a failure.
            if cancelledJobIDs.contains(jobID) {
                mark(jobID, state: .cancelled, message: nil)
                cancelledJobIDs.remove(jobID)
            } else {
                // The sidecar's own message is always more useful than the exit
                // status that follows it.
                mark(jobID, state: .failed,
                     message: sidecarFailure ?? error.localizedDescription)
            }
            try? FileManager.default.removeItem(at: scratch)
        }
    }

    /// Folds one sidecar event into the job's state.
    ///
    /// Separated from `run` so the render loop reads as what it is — start the
    /// process, consume events, post-process — rather than burying that shape
    /// under a long switch.
    private func apply(_ event: SidecarEvent,
                       to jobID: UUID,
                       video: inout URL?,
                       failure: inout String?) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }

        switch event {
        case .stage(let state):
            jobs[index].state = state
        case .step(let completed, let total, let perStep):
            jobs[index].state = .generating
            jobs[index].completedSteps = completed
            jobs[index].totalSteps = total
            jobs[index].secondsPerStep = perStep
            jobs[index].progress = total > 0 ? Double(completed) / Double(total) : 0
        case .memory(let bytes):
            jobs[index].peakMemoryBytes = max(jobs[index].peakMemoryBytes ?? 0, bytes)
        case .seed(let seed):
            jobs[index].resolvedSeed = seed
        case .artifact(let url, _):
            video = url
        case .log(let message):
            appendLog(message)
        case .failure(let message):
            failure = message
            appendLog("Error: \(message)")
        case .finishedOK, .downloadProgress:
            break
        }
    }

    private func mark(_ jobID: UUID, state: RenderJob.State, message: String?) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[index].state = state
        jobs[index].finishedAt = .now
        jobs[index].failureMessage = message
    }

    private func appendLog(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentLog.append(trimmed)
        if currentLog.count > 400 { currentLog.removeFirst(currentLog.count - 400) }
    }

    // MARK: - Job file

    /// Serialises the spec into the flat shape the sidecar expects, resolving every
    /// catalog reference to a real path on disk.
    private func writeJobFile(spec: GenerationSpec, rawOutput: URL, to url: URL) throws {
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

    // MARK: - Persistence

    nonisolated static var scratchDirectory: URL {
        RuntimeManager.supportDirectory.appending(path: "scratch", directoryHint: .isDirectory)
    }

    nonisolated private static var queueURL: URL {
        RuntimeManager.supportDirectory.appending(path: "queue.json")
    }

    private func persist() {
        let snapshot = jobs
        Task.detached(priority: .background) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? FileManager.default.createDirectory(
                at: RuntimeManager.supportDirectory, withIntermediateDirectories: true)
            try? data.write(to: RenderEngine.queueURL, options: .atomic)
        }
    }

    nonisolated private static func loadQueue() -> [RenderJob] {
        guard let data = try? Data(contentsOf: queueURL),
              let jobs = try? JSONDecoder().decode([RenderJob].self, from: data)
        else { return [] }
        return jobs
    }

    enum EngineError: LocalizedError {
        case sidecar(String)
        case noOutput

        var errorDescription: String? {
            switch self {
            case .sidecar(let message): message
            case .noOutput: "The render finished but produced no video file."
            }
        }
    }
}
