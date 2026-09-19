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
    /// Sidecar output per job, so each row can show its own log rather than
    /// sharing one buffer that only ever held the active render.
    private(set) var logs: [UUID: [String]] = [:]
    /// Failure messages a backend reported before throwing.
    private var reportedFailures: [UUID: String] = [:]

    private let runtime: RuntimeManager
    private let modelStore: ModelStore
    private let library: LibraryStore

    private let mlx: MLXBackend
    private let comfy: ComfyUIBackend

    private var activeTask: Task<Void, Never>?
    private var cancelledJobIDs = Set<UUID>()
    /// The backend serving the job in flight, so cancel reaches the right one.
    private var activeBackend: (any RenderBackend)?

    init(runtime: RuntimeManager,
         comfyRuntime: ComfyUIRuntime,
         modelStore: ModelStore,
         library: LibraryStore) {
        self.runtime = runtime
        self.modelStore = modelStore
        self.library = library
        self.mlx = MLXBackend(runtime: runtime, modelStore: modelStore)
        self.comfy = ComfyUIBackend(runtime: comfyRuntime, modelStore: modelStore)
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
            let backend = activeBackend
            Task { await backend?.cancel() }
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

    /// Starts the first queued job that is not being held.
    func startNextIfIdle() {
        guard !isRunning, runtime.phase.isReady,
              let next = jobs.first(where: { $0.state == .queued && !$0.isHeld })
        else { return }
        activeTask = Task { await run(jobID: next.id) }
    }

    /// Holds a queued job back, or releases it. Replaces the old global
    /// auto-start switch: control belongs to the individual render, since that
    /// is what the user is actually deciding about.
    func setHeld(_ held: Bool, for id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].isHeld = held
        persist()
        if !held { startNextIfIdle() }
    }

    func log(for id: UUID) -> [String] { logs[id] ?? [] }

    /// Picks the backend for a spec.
    ///
    /// Reference conditioning exists only in ComfyUI. Everything else defaults to
    /// MLX, which is native and needs no server, unless the spec asks otherwise.
    func backend(for spec: GenerationSpec) -> any RenderBackend {
        if let preferred = spec.backend {
            return preferred == .comfyUI ? comfy : mlx
        }
        return mlx.supports(spec.mode) ? mlx : comfy
    }

    /// Why this spec cannot run right now, or nil.
    func unavailableReason(for spec: GenerationSpec) -> String? {
        backend(for: spec).unavailableReason(for: spec)
    }

    private func run(jobID: UUID) async {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        isRunning = true
        logs[jobID] = []
        reportedFailures[jobID] = nil
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

        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

            let chosen = backend(for: spec)
            activeBackend = chosen
            jobs[index].backend = chosen.id
            appendLog("Rendering with \(chosen.id.label).", to: jobID)

            // Events arrive off the main actor; hop back before touching state.
            let sink: @Sendable (SidecarEvent) -> Void = { event in
                Task { @MainActor [weak self] in
                    guard let self, self.jobs.contains(where: { $0.id == jobID }) else { return }
                    var ignoredVideo: URL?
                    var reported: String?
                    self.apply(event, to: jobID, video: &ignoredVideo, failure: &reported)
                    if let reported { self.reportedFailures[jobID] = reported }
                }
            }

            let rawVideoURL = try await chosen.run(spec: spec, scratch: scratch, events: sink)

            if cancelledJobIDs.contains(jobID) { throw CancellationError() }
            if let reported = reportedFailures[jobID] { throw EngineError.sidecar(reported) }
            guard FileManager.default.fileExists(atPath: rawVideoURL.path) else {
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
                // A backend reports why it failed before it throws; that message
                // is always more useful than the transport-level error.
                mark(jobID, state: .failed,
                     message: reportedFailures[jobID] ?? error.localizedDescription)
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
            // A new stage invalidates the previous stage's sub-progress.
            jobs[index].stageProgress = nil
            jobs[index].stageDetail = nil
        case .substage(_, let completed, let total, let detail):
            jobs[index].stageProgress = total > 0 ? Double(completed) / Double(total) : nil
            jobs[index].stageDetail = detail
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
            appendLog(message, to: jobID)
        case .failure(let message):
            failure = message
            appendLog("Error: \(message)", to: jobID)
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

    private func appendLog(_ message: String, to jobID: UUID) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var lines = logs[jobID] ?? []
        lines.append(trimmed)
        // A failing render can emit thousands of lines; keep a useful tail.
        if lines.count > 600 { lines.removeFirst(lines.count - 600) }
        logs[jobID] = lines
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
