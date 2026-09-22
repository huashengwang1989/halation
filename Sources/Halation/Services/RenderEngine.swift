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
    /// When each job's log was last written out, for the flush interval.
    private var lastLogFlush: [UUID: Date] = [:]
    /// Memory in use while a render runs, split between the app and the engine.
    ///
    /// Both halves, because they are wildly different sizes and only one of them
    /// is interesting: the app holds a few hundred megabytes while the engine
    /// holds tens of gigabytes. Showing only the app's — which is what this did
    /// until the two were separated — reported 712 MB during a render that was
    /// using ninety-four gigabytes.
    struct MemoryUsage: Sendable, Equatable {
        var appBytes: Int64
        var engineBytes: Int64
        /// Highest total reached during this render.
        ///
        /// From the kernel's own lifetime maximum rather than the highest value
        /// this sampler happened to see. On a measured render the two differed
        /// by 14 GB — 120 GB peak against 106 GB when next polled — because a
        /// two-second poll cannot catch a spike between samples.
        var peakTotalBytes: Int64

        var totalBytes: Int64 { appBytes + engineBytes }
    }

    private(set) var memoryUsage: MemoryUsage?
    private var memoryTask: Task<Void, Never>?

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
        logs = Self.loadLogs(for: jobs.map(\.id))
        // A job that was mid-flight when the app quit cannot be resumed inside the
        // sidecar, so it returns to the queue rather than lying about its state.
        //
        // An abrupt quit cannot write its own epitaph, so this is where it gets
        // written: a job still marked active in the file is one the app did not
        // finish with, however it went away.
        for index in jobs.indices where jobs[index].state.isActive {
            jobs[index].state = .queued
            jobs[index].progress = 0
            jobs[index].completedSteps = 0
            let stamp = Self.logTime.string(from: .now)
            var lines = logs[jobs[index].id] ?? []
            lines.append("[\(stamp)] Interrupted: the app stopped while this was running.")
            lines.append("[\(stamp)] Back in the queue after restart.")
            logs[jobs[index].id] = lines
            // Written straight away: this is the only record that the previous
            // run ended the way it did, and the app may not get another chance.
            writeLog(lines, for: jobs[index].id)
        }
    }

    // MARK: - Queue management

    func enqueue(_ spec: GenerationSpec) -> RenderJob {
        Notifier.shared.requestPermissionIfNeeded()
        let job = RenderJob(spec: spec)
        jobs.append(job)
        note("Queued.", to: job.id)
        persist()
        startNextIfIdle()
        return job
    }

    func cancel(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        // Logged here rather than at the button, so the context menu, the
        // toolbar and any future shortcut all record the same event once.
        InteractionLog.shared.record(.click, "queue.cancel",
                                     value: jobs[index].state.rawValue)
        if jobs[index].state.isActive {
            note("Cancelled while running.", to: id)
            cancelledJobIDs.insert(id)
            activeTask?.cancel()
            let backend = activeBackend
            Task { await backend?.cancel() }
        } else {
            note("Cancelled before it started.", to: id)
            jobs[index].state = .cancelled
            jobs[index].finishedAt = .now
            flushLog(for: id)
            persist()
        }
    }

    func remove(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        if jobs[index].state.isActive { cancel(id); return }
        jobs.remove(at: index)
        logs[id] = nil
        persist()
        pruneLogs()
    }

    func clearFinished() {
        let removed = jobs.filter { $0.state.isTerminal }.map(\.id)
        InteractionLog.shared.record(.click, "queue.clearFinished",
                                     value: "\(removed.count)")
        jobs.removeAll { $0.state.isTerminal }
        for id in removed { logs[id] = nil }
        persist()
        pruneLogs()
    }

    /// Re-queues a failed or finished job with the same spec and a fresh seed.
    func retry(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        InteractionLog.shared.record(.click, "queue.retry")
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
        InteractionLog.shared.record(.toggle, "queue.hold", value: held ? "held" : "released")
        jobs[index].isHeld = held
        note(held ? "Held." : "Released.", to: id)
        flushLog(for: id)
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
        // The log is deliberately *not* cleared here. It already holds when the
        // job was queued, and whether a previous attempt was interrupted by the
        // app going away — which is the history a second attempt most needs.
        // A retry proper gets a new job and so a new log anyway.
        lastLogFlush[jobID] = nil
        reportedFailures[jobID] = nil
        defer {
            isRunning = false
            persist()
            startNextIfIdle()
        }

        jobs[index].state = .preparing
        jobs[index].startedAt = .now
        jobs[index].progress = 0
        // Written out now, not only in the `defer` at the end. Without this the
        // file still says "queued" for the whole render, so a crash or a force
        // quit leaves nothing to distinguish "never started" from "was killed
        // half way" — and the restart note below depends on telling them apart.
        persist()

        let spec = jobs[index].spec
        let scratch = Self.scratchDirectory.appending(path: jobID.uuidString, directoryHint: .isDirectory)

        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

            let chosen = backend(for: spec)
            activeBackend = chosen
            jobs[index].backend = chosen.id
            note("Started on \(chosen.id.label).", to: jobID)

            // Events arrive off the main actor; hop back before touching state.
            let sink: @Sendable (SidecarEvent) -> Void = { [weak self] event in
                Task { @MainActor in
                    guard let self, self.jobs.contains(where: { $0.id == jobID }) else { return }
                    var ignoredVideo: URL?
                    var reported: String?
                    self.apply(event, to: jobID, video: &ignoredVideo, failure: &reported)
                    if let reported { self.reportedFailures[jobID] = reported }
                }
            }

            startSamplingMemory(from: chosen)
            defer { stopSamplingMemory() }

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
            Notifier.shared.renderFinished(jobs[finalIndex])
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
        case .step(let completed, let total, let perStep, let recent):
            jobs[index].state = .generating
            jobs[index].completedSteps = completed
            jobs[index].totalSteps = total
            jobs[index].secondsPerStep = perStep
            jobs[index].secondsPerStepRecent = recent
            jobs[index].progress = total > 0 ? Double(completed) / Double(total) : 0
        case .promptTokens(let total, let text):
            jobs[index].promptTokenCount = total
            jobs[index].promptTextTokenCount = text
        case .memory(let bytes, let active):
            jobs[index].peakMemoryBytes = max(jobs[index].peakMemoryBytes ?? 0, bytes)
            if let active { EngineMetalMemory.record(active) }
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

    /// Polls memory while the engine works.
    ///
    /// Sampled rather than reported by the backends because only MLX emits a
    /// figure of its own, and that one is a peak; the status bar wants what is
    /// held now, on whichever engine is running.
    private func startSamplingMemory(from backend: any RenderBackend) {
        memoryTask?.cancel()
        memoryTask = Task { [weak self] in
            while !Task.isCancelled {
                let engine = await backend.currentMemoryBytes() ?? 0
                let enginePeak = await backend.peakMemoryBytes() ?? engine
                let app = ProcessMemory.ownFootprintBytes
                let appPeak = ProcessMemory.peakFootprintBytes(of: getpid()) ?? app
                await MainActor.run {
                    guard let self else { return }
                    let peak = max(self.memoryUsage?.peakTotalBytes ?? 0, appPeak + enginePeak)
                    self.memoryUsage = .init(appBytes: app, engineBytes: engine,
                                             peakTotalBytes: peak)
                    // Carried onto the job too, so the Queue row still shows a
                    // peak after the render ends and this value is cleared.
                    if let index = self.jobs.firstIndex(where: { $0.state.isActive }) {
                        self.jobs[index].peakMemoryBytes =
                            max(self.jobs[index].peakMemoryBytes ?? 0, peak)
                    }
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func stopSamplingMemory() {
        memoryTask?.cancel()
        memoryTask = nil
        memoryUsage = nil
    }

    private func mark(_ jobID: UUID, state: RenderJob.State, message: String?) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[index].state = state
        jobs[index].finishedAt = .now
        jobs[index].failureMessage = message
        // Failures only. A cancellation was the user's own doing a moment ago,
        // so announcing it tells them something they already know.
        if state == .failed { Notifier.shared.renderFailed(jobs[index]) }

        switch state {
        case .finished: note("Finished.", to: jobID)
        case .cancelled: note("Stopped.", to: jobID)
        case .failed: note("Failed\(message.map { ": \($0)" } ?? ".")", to: jobID)
        default: break
        }
        // The log stops changing here and starts mattering, so do not wait out
        // the flush interval.
        flushLog(for: jobID)
    }

    /// Records something that happened *to* a job rather than something its
    /// engine said: a click, a scheduling decision, the app coming and going.
    ///
    /// English, like the rest of the log: these lines get pasted into bug
    /// reports, and a diagnostic that changes language with the interface is
    /// harder to help with, not easier.
    private func note(_ message: String, to jobID: UUID) {
        appendLog(message, to: jobID)
    }

    /// RFC 3339, with a space instead of the `T` — which that standard permits —
    /// and the offset kept.
    ///
    /// The date matters because a render runs for hours and a queue survives
    /// restarts, so "21:47" alone cannot say which day. The offset matters
    /// because these logs get pasted into reports read by someone in another
    /// zone. Fixed to `en_US_POSIX` so the shape never changes with the
    /// interface language: a machine-readable stamp is the one part of a log
    /// that should not be localised.
    nonisolated static let logTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssXXXXX"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Every line is stamped, engine output included. A log whose entries
    /// cannot be placed in time is much less use for the thing it is for:
    /// working out where a long render actually went.
    private func appendLog(_ message: String, to jobID: UUID) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var lines = logs[jobID] ?? []
        lines.append("[\(Self.logTime.string(from: .now))] \(trimmed)")
        // A failing render can emit thousands of lines; keep a useful tail.
        if lines.count > 600 { lines.removeFirst(lines.count - 600) }
        logs[jobID] = lines

        // Written through, but not on every line: a render emits them in
        // bursts, and the whole tail is rewritten each time so the file never
        // grows past what the sheet shows. A crash costs at most this interval.
        let now = Date()
        if now.timeIntervalSince(lastLogFlush[jobID] ?? .distantPast) > 2 {
            lastLogFlush[jobID] = now
            writeLog(lines, for: jobID)
        }
    }

    /// Flushes without waiting for the interval. Called when a job reaches a
    /// terminal state, which is exactly when its log stops changing and starts
    /// mattering.
    private func flushLog(for jobID: UUID) {
        lastLogFlush[jobID] = Date()
        writeLog(logs[jobID] ?? [], for: jobID)
    }

    // MARK: - Persistence

    nonisolated static var scratchDirectory: URL {
        RuntimeManager.supportDirectory.appending(path: "scratch", directoryHint: .isDirectory)
    }

    nonisolated private static var queueURL: URL {
        RuntimeManager.supportDirectory.appending(path: "queue.json")
    }

    /// Job logs, one plain-text file each, beside the queue they belong to.
    ///
    /// Here rather than next to the finished video, where the metadata sidecar
    /// lives, because the log matters most for the jobs that never produce a
    /// video. A failed render has nothing in the library to sit beside, and
    /// that is the one whose log a person actually wants tomorrow.
    nonisolated static var logsDirectory: URL {
        RuntimeManager.supportDirectory.appending(path: "logs", directoryHint: .isDirectory)
    }

    nonisolated private static func logURL(for id: UUID) -> URL {
        logsDirectory.appending(path: "\(id.uuidString).log")
    }

    private func writeLog(_ lines: [String], for id: UUID) {
        let text = lines.joined(separator: "\n")
        let url = Self.logURL(for: id)
        Task.detached(priority: .background) {
            try? FileManager.default.createDirectory(
                at: RenderEngine.logsDirectory, withIntermediateDirectories: true)
            try? Data(text.utf8).write(to: url, options: .atomic)
        }
    }

    nonisolated private static func loadLogs(for ids: [UUID]) -> [UUID: [String]] {
        var result: [UUID: [String]] = [:]
        for id in ids {
            guard let text = try? String(contentsOf: logURL(for: id), encoding: .utf8),
                  !text.isEmpty else { continue }
            result[id] = text.components(separatedBy: "\n")
        }
        return result
    }

    /// Deletes the log files of jobs that are no longer in the queue, so the
    /// directory cannot outlive what it documents.
    private func pruneLogs() {
        let keep = Set(jobs.map(\.id))
        Task.detached(priority: .background) {
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(
                at: RenderEngine.logsDirectory, includingPropertiesForKeys: nil) else { return }
            for file in files where file.pathExtension == "log" {
                let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent)
                if id == nil || !keep.contains(id!) { try? fm.removeItem(at: file) }
            }
        }
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
