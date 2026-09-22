import Foundation

/// Drives a headless ComfyUI over its HTTP + websocket API.
///
/// The only backend that implements reference conditioning, and the only one that
/// can load a turbo LoRA — which is what makes Ref2VA practical at all. Measured:
/// 1344×768, 124 frames, 4 steps, 26m47s on an M4 Max.
actor ComfyUIBackend: RenderBackend {
    nonisolated var id: BackendID { .comfyUI }

    private let runtime: ComfyUIRuntime
    private let modelStore: ModelStore
    private var currentPromptID: String?
    /// Where the previous progress report left off, for the per-step timing.
    private var lastProgressAt: Date?
    private var lastProgressValue = 0
    private var socket: URLSessionWebSocketTask?

    init(runtime: ComfyUIRuntime, modelStore: ModelStore) {
        self.runtime = runtime
        self.modelStore = modelStore
    }

    nonisolated func supports(_ mode: GenerationMode) -> Bool {
        // ComfyUI implements every mode; reference conditioning is its reason for
        // existing here, but it can do the others too.
        true
    }

    @MainActor func unavailableReason(for spec: GenerationSpec) -> String? {
        guard runtime.isInstalled else {
            return loc("comfy.notInstalled")
        }
        let missing = ComfyUIModelSet.missing(in: modelStore.rootURL, for: spec.task)
        guard missing.isEmpty else {
            // Backticked so the file names are set apart from the sentence;
            // `CodeSpanText` renders them.
            return loc("comfy.missingWeights",
                       missing.map { "`\($0)`" }.joined(separator: ", "))
        }
        return nil
    }

    // MARK: - Run

    func run(spec: GenerationSpec,
             scratch: URL,
             events: @escaping @Sendable (SidecarEvent) -> Void) async throws -> URL {
        events(.stage(.preparing))
        events(.log("Starting ComfyUI…"))
        try await runtime.ensureServerRunning()

        let base = await runtime.baseURL
        let modelsRoot = await runtime.modelsRoot
        guard let models = ComfyUIModelSet.resolve(in: modelsRoot.deletingLastPathComponent(),
                                                   task: spec.task) else {
            throw BackendError.unsupported("The ComfyUI weights for \(spec.task.rawValue) are not installed.")
        }

        // References must be inside ComfyUI's own input directory.
        let inputDir = ComfyUIRuntime.rootURL.appending(path: "input", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: inputDir, withIntermediateDirectories: true)
        let uploaded = try stageReferences(spec: spec, into: inputDir)

        let seed = spec.sampling.seed ?? Int64.random(in: 0..<Int64(1) << 47)
        events(.seed(seed))

        let workflow = ComfyUIWorkflow(
            spec: spec, models: models, seed: seed,
            referenceImages: uploaded,
            outputPrefix: "halation/\(UUID().uuidString.prefix(8))")

        let clientID = UUID().uuidString
        try await openSocket(base: base, clientID: clientID)
        defer { socket?.cancel(with: .goingAway, reason: nil) }

        let promptID = try await submit(graph: workflow.graph(), clientID: clientID, base: base)
        currentPromptID = promptID
        events(.log("Queued as \(promptID)"))

        try await followProgress(promptID: promptID, base: base,
                                 totalSteps: spec.sampling.steps, events: events)

        return try await collectOutput(promptID: promptID, base: base, into: scratch, events: events)
    }

    func cancel() async {
        guard let promptID = currentPromptID, let base = await runtime.baseURL as URL? else { return }
        // Clear it from the queue and interrupt whatever is executing.
        _ = try? await post(["delete": [promptID]], to: base.appending(path: "queue"))
        _ = try? await post([:], to: base.appending(path: "interrupt"))
        socket?.cancel(with: .goingAway, reason: nil)
    }

    func currentMemoryBytes() async -> Int64? {
        // The work happens in the ComfyUI server, not in this process.
        guard let pid = await runtime.serverProcessIdentifier else { return nil }
        return ProcessMemory.treeFootprintBytes(of: pid)
    }

    func peakMemoryBytes() async -> Int64? {
        guard let pid = await runtime.serverProcessIdentifier else { return nil }
        return ProcessMemory.treePeakFootprintBytes(of: pid)
    }

    // MARK: - References

    /// Copies attached images into ComfyUI's input folder under unique names.
    ///
    /// Order matters and differs by mode: reference mode uses prompt order, while
    /// keyframe modes expect the first frame at index 0 and the last at index 1.
    private func stageReferences(spec: GenerationSpec, into inputDir: URL) throws -> [String] {
        var images = spec.references.filter { $0.kind == .image }
        if spec.mode == .firstAndLastFrame || spec.mode == .firstFrame {
            images.sort { lhs, _ in lhs.slot == .first }
        }
        var names: [String] = []
        for (index, asset) in images.enumerated() {
            let name = "halation_ref_\(UUID().uuidString.prefix(8))_\(index).\(asset.url.pathExtension)"
            let destination = inputDir.appending(path: name)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: asset.url, to: destination)
            names.append(name)
        }
        return names
    }

    // MARK: - HTTP

    private func submit(graph: [String: Any], clientID: String, base: URL) async throws -> String {
        let payload: [String: Any] = ["prompt": graph, "client_id": clientID]
        let data = try await post(payload, to: base.appending(path: "prompt"))
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let promptID = object["prompt_id"] as? String else {
            // ComfyUI returns a structured validation error; surface it verbatim
            // rather than a generic failure.
            let text = String(data: data, encoding: .utf8) ?? "unreadable response"
            throw BackendError.reported("ComfyUI rejected the workflow: \(text.prefix(600))")
        }
        return promptID
    }

    @discardableResult
    private func post(_ payload: [String: Any], to url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw BackendError.reported("ComfyUI returned \(http.statusCode): \(text.prefix(600))")
        }
        return data
    }

    private func get(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Progress

    private func openSocket(base: URL, clientID: String) async throws {
        var components = URLComponents(url: base.appending(path: "ws"), resolvingAgainstBaseURL: false)
        components?.scheme = "ws"
        components?.queryItems = [URLQueryItem(name: "clientId", value: clientID)]
        guard let url = components?.url else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        socket = task
    }

    /// Consumes websocket messages until the prompt finishes.
    ///
    /// ComfyUI reports `progress` (step counts), `executing` (current node) and
    /// `execution_error`. The history endpoint is the authority on completion, so
    /// the socket is a progress feed rather than the source of truth.
    private func followProgress(promptID: String, base: URL, totalSteps: Int,
                                events: @escaping @Sendable (SidecarEvent) -> Void) async throws {
        let started = Date()
        var sawCompletion = false

        while !sawCompletion {
            try Task.checkCancellation()

            // Prefer the socket, but never rely on it: fall back to history polling
            // if it drops, or a long render would stall silently.
            if let socket {
                do {
                    let message = try await withTimeout(seconds: 20) {
                        try await socket.receive()
                    }
                    if let text = Self.text(of: message),
                       let event = Self.parse(text, totalSteps: totalSteps, started: started) {
                        switch timed(event) {
                        case .failure(let message):
                            throw BackendError.reported(message)
                        case .finishedOK:
                            sawCompletion = true
                        default:
                            events(event)
                        }
                    }
                } catch is TimeoutError {
                    // No news; fall through to the history check.
                } catch let error as BackendError {
                    throw error
                } catch {
                    self.socket = nil
                    events(.log("Progress socket dropped; polling instead."))
                }
            } else {
                try await Task.sleep(for: .seconds(5))
            }

            let history = try await get(base.appending(path: "history/\(promptID)"))
            if let entry = history[promptID] as? [String: Any] {
                let status = entry["status"] as? [String: Any] ?? [:]
                if (status["status_str"] as? String) == "error" {
                    throw BackendError.reported(Self.errorText(from: status))
                }
                if status["completed"] as? Bool == true { sawCompletion = true }
            }
        }
    }

    /// Fills in how long the latest steps took.
    ///
    /// ComfyUI reports a running count, not a duration, so the gap between two
    /// reports is the only measurement available. Kept here rather than in
    /// `parse`, which is static and deliberately has no memory.
    private func timed(_ event: SidecarEvent) -> SidecarEvent {
        guard case .step(let completed, let total, let perStep, _) = event else { return event }
        defer {
            lastProgressAt = Date()
            lastProgressValue = completed
        }
        guard let since = lastProgressAt, completed > lastProgressValue else { return event }
        let recent = Date().timeIntervalSince(since) / Double(completed - lastProgressValue)
        return .step(completed: completed, total: total,
                     secondsPerStep: perStep, recentSeconds: recent)
    }

    private static func text(of message: URLSessionWebSocketTask.Message) -> String? {
        if case .string(let text) = message { return text }
        return nil
    }

    private static func parse(_ text: String, totalSteps: Int, started: Date) -> SidecarEvent? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { return nil }
        let payload = object["data"] as? [String: Any] ?? [:]

        switch type {
        case "progress":
            let value = payload["value"] as? Int ?? 0
            let max = payload["max"] as? Int ?? totalSteps
            let elapsed = Date().timeIntervalSince(started)
            let perStep = value > 0 ? elapsed / Double(value) : nil
            // `recentSeconds` is filled in by the caller, which is the only place
            // that remembers where the previous progress report left off.
            return .step(completed: value, total: max, secondsPerStep: perStep,
                         recentSeconds: nil)
        case "executing":
            guard let node = payload["node"] as? String else { return .finishedOK }
            if let stage = ComfyUIWorkflow.stage(forNode: node) {
                return .stage(stage)
            }
            return .log(ComfyUIWorkflow.nodeLabel(node))
        case "execution_error":
            return .failure(Self.errorText(from: payload))
        case "execution_success":
            return .finishedOK
        default:
            return nil
        }
    }

    private static func errorText(from payload: [String: Any]) -> String {
        if let message = payload["exception_message"] as? String {
            let node = payload["node_type"] as? String
            return node.map { "\($0): \(message)" } ?? message
        }
        if let messages = payload["messages"] as? [[Any]] {
            for entry in messages.reversed() where entry.count > 1 {
                if let detail = entry[1] as? [String: Any],
                   let message = detail["exception_message"] as? String {
                    return message
                }
            }
        }
        return loc("comfy.executionError")
    }

    // MARK: - Output

    private func collectOutput(promptID: String, base: URL, into scratch: URL,
                               events: @escaping @Sendable (SidecarEvent) -> Void) async throws -> URL {
        let history = try await get(base.appending(path: "history/\(promptID)"))
        guard let entry = history[promptID] as? [String: Any],
              let outputs = entry["outputs"] as? [String: Any] else {
            throw BackendError.noOutput
        }

        // SaveVideo reports under a key that has varied between versions, so take
        // the first entry that looks like a file.
        for (_, value) in outputs {
            guard let bucket = value as? [String: Any] else { continue }
            for key in ["videos", "gifs", "images", "audio"] {
                guard let files = bucket[key] as? [[String: Any]] else { continue }
                for file in files {
                    guard let filename = file["filename"] as? String else { continue }
                    let subfolder = file["subfolder"] as? String ?? ""
                    let type = file["type"] as? String ?? "output"
                    var components = URLComponents(
                        url: base.appending(path: "view"), resolvingAgainstBaseURL: false)
                    components?.queryItems = [
                        URLQueryItem(name: "filename", value: filename),
                        URLQueryItem(name: "subfolder", value: subfolder),
                        URLQueryItem(name: "type", value: type),
                    ]
                    guard let url = components?.url else { continue }

                    events(.log("Fetching \(filename)"))
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let destination = scratch.appending(path: filename)
                    try data.write(to: destination, options: .atomic)
                    events(.artifact(video: destination, audio: nil))
                    return destination
                }
            }
        }
        throw BackendError.noOutput
    }
}

// MARK: - Timeout

private struct TimeoutError: Error {}

private func withTimeout<T: Sendable>(seconds: Double,
                                      _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        guard let first = try await group.next() else { throw TimeoutError() }
        group.cancelAll()
        return first
    }
}
