import Foundation
import Observation

/// Installs and supervises a private, headless ComfyUI.
///
/// Deliberately separate from the MLX runtime: ComfyUI needs PyTorch, which
/// conflicts with the MLX environment, and the user's own ComfyUI install must be
/// left alone. This one lives under Application Support and is disposable.
@MainActor
@Observable
final class ComfyUIRuntime {
    enum Phase: Equatable, Sendable {
        case unknown
        case missing
        case installing(step: String)
        case ready(version: String)
        case failed(String)

        var isBusy: Bool { if case .installing = self { true } else { false } }
        var isReady: Bool { if case .ready = self { true } else { false } }
    }

    private(set) var phase: Phase = .unknown
    private(set) var installLog: [String] = []
    private(set) var isServerRunning = false
    /// Port the supervised server is listening on.
    private(set) var port: Int = 8188

    private let modelStore: ModelStore
    private var serverRunner: ProcessRunner?
    private var serverTask: Task<Void, Never>?

    init(modelStore: ModelStore) {
        self.modelStore = modelStore
    }

    // MARK: - Locations

    nonisolated static var rootURL: URL {
        RuntimeManager.supportDirectory.appending(path: "comfyui", directoryHint: .isDirectory)
    }

    nonisolated var pythonURL: URL { Self.rootURL.appending(path: ".venv/bin/python") }
    nonisolated var mainScript: URL { Self.rootURL.appending(path: "main.py") }

    /// ComfyUI's models live in the shared folder alongside the MLX weights.
    var modelsRoot: URL {
        modelStore.rootURL.appending(path: "comfyui", directoryHint: .isDirectory)
    }

    nonisolated static let repositoryURL = "https://github.com/comfyanonymous/ComfyUI.git"

    var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: pythonURL.path)
            && FileManager.default.fileExists(atPath: mainScript.path)
    }

    var baseURL: URL { URL.literal("http://127.0.0.1:\(port)") }

    func environment() -> [String: String] {
        var env: [String: String] = [
            // Several H3 ops have no Metal kernel; without this the process
            // aborts instead of falling back to CPU for those.
            "PYTORCH_ENABLE_MPS_FALLBACK": "1",
            "PYTHONUNBUFFERED": "1",
            "HF_HOME": modelStore.huggingFaceHome.path,
        ]
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
        return env
    }

    // MARK: - Install

    func refresh() async {
        guard isInstalled else {
            phase = .missing
            return
        }
        let version = readVersion() ?? "unknown"
        phase = .ready(version: version)
    }

    private func readVersion() -> String? {
        let file = Self.rootURL.appending(path: "comfyui_version.py")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        guard let range = text.range(of: #"__version__\s*=\s*"([^"]+)""#, options: .regularExpression),
              let quoted = text[range].range(of: #""([^"]+)""#, options: .regularExpression)
        else { return nil }
        return String(text[quoted].dropFirst().dropLast())
    }

    func install(reinstall: Bool = false) async {
        installLog.removeAll()
        phase = .installing(step: "Preparing")

        do {
            let fm = FileManager.default
            try fm.createDirectory(at: RuntimeManager.supportDirectory, withIntermediateDirectories: true)
            if reinstall, fm.fileExists(atPath: Self.rootURL.path) {
                append("Removing the previous ComfyUI…")
                try fm.removeItem(at: Self.rootURL)
            }

            phase = .installing(step: "Fetching ComfyUI")
            try await syncCheckout()

            phase = .installing(step: "Creating the Python environment")
            let uv = try await locateUV()
            try await run(uv, ["venv", Self.rootURL.appending(path: ".venv").path, "--python", "3.12"])

            phase = .installing(step: "Installing PyTorch and dependencies")
            try await run(uv, ["pip", "install", "--python", pythonURL.path,
                               "--requirement", Self.rootURL.appending(path: "requirements.txt").path])

            phase = .installing(step: "Wiring up the shared models folder")
            try writeModelPaths()
            try writeMemoryProbe()

            await refresh()
        } catch {
            append("Install failed: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    private func syncCheckout() async throws {
        let git = URL(fileURLWithPath: "/usr/bin/git")
        let fm = FileManager.default
        if fm.fileExists(atPath: Self.rootURL.appending(path: ".git").path) {
            append("Updating the existing checkout…")
            try await run(git, ["-C", Self.rootURL.path, "pull", "--ff-only"])
        } else {
            if fm.fileExists(atPath: Self.rootURL.path) { try fm.removeItem(at: Self.rootURL) }
            append("Cloning ComfyUI…")
            try await run(git, ["clone", "--depth", "1", Self.repositoryURL, Self.rootURL.path])
        }
    }

    /// Points ComfyUI at the shared models folder, so its weights sit beside the
    /// MLX ones and are not duplicated inside the checkout.
    func writeModelPaths() throws {
        let root = modelsRoot
        for sub in ["diffusion_models", "text_encoders", "vae", "loras"] {
            try FileManager.default.createDirectory(
                at: root.appending(path: sub), withIntermediateDirectories: true)
        }
        let yaml = """
            # Written by Halation. Points ComfyUI at the shared models folder so its
            # weights live beside the MLX ones rather than inside the checkout.
            halation:
              base_path: \(root.path)
              diffusion_models: diffusion_models
              text_encoders: text_encoders
              vae: vae
              loras: loras
            """
        try yaml.write(to: Self.rootURL.appending(path: "extra_model_paths.yaml"),
                       atomically: true, encoding: .utf8)
    }

    /// Installs a one-file custom node that reports what Torch is holding on the
    /// GPU, because nothing ComfyUI ships does.
    ///
    /// `/system_stats` looks like the right endpoint and is not: on MPS,
    /// `get_free_memory` returns *system* memory available for both `vram_free`
    /// and `torch_vram_free` (model_management.py, the `dev.type == 'mps'`
    /// branch), so the figures have nothing to do with Metal. `torch.mps` knows
    /// exactly, but only from inside the server's own process — hence a route.
    ///
    /// Written on every launch rather than only at install, so an existing
    /// checkout picks it up without being reinstalled. It adds a route and
    /// nothing else: no nodes, no imports at graph-evaluation time.
    func writeMemoryProbe() throws {
        let directory = Self.rootURL.appending(path: "custom_nodes/halation_memory")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = """
            # Written by Halation. Reports Torch's own Metal allocation, which
            # ComfyUI's /system_stats does not expose on MPS.
            from server import PromptServer
            from aiohttp import web

            NODE_CLASS_MAPPINGS = {}
            NODE_DISPLAY_NAME_MAPPINGS = {}


            @PromptServer.instance.routes.get("/halation/memory")
            async def halation_memory(request):
                allocated = driver = 0
                try:
                    import torch

                    if torch.backends.mps.is_available():
                        allocated = int(torch.mps.current_allocated_memory())
                        driver = int(torch.mps.driver_allocated_memory())
                except Exception:
                    pass
                # `driver` is the pool Torch has taken from Metal; `allocated` is
                # the part of it currently holding tensors. The pool is what the
                # machine has actually given up, so it is the honest figure.
                return web.json_response({"allocated": allocated, "driver": driver})
            """
        try source.write(to: directory.appending(path: "__init__.py"),
                         atomically: true, encoding: .utf8)
    }

    /// What Torch holds on the GPU right now, or `nil` if the server is not up.
    ///
    /// Polled rather than pushed: ComfyUI is an HTTP server and answers this
    /// while a render runs, which is the whole point — a figure that only
    /// arrived between jobs would be useless on a chart.
    func metalBytes() async -> Int64? {
        guard isServerRunning else { return nil }
        var request = URLRequest(url: baseURL.appending(path: "halation/memory"))
        request.timeoutInterval = 0.8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let driver = json["driver"] as? Int
        else { return nil }
        return Int64(driver)
    }

    private func locateUV() async throws -> URL {
        let fm = FileManager.default
        let managed = RuntimeManager.supportDirectory.appending(path: "bin/uv")
        if fm.isExecutableFile(atPath: managed.path) { return managed }
        for candidate in ["/opt/homebrew/bin/uv", "/usr/local/bin/uv"]
        where fm.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        throw ComfyError.uvMissing
    }

    // MARK: - Server

    /// Starts the server if it is not already answering, and waits until it is.
    func ensureServerRunning() async throws {
        if await ping() { isServerRunning = true; return }
        guard isInstalled else { throw ComfyError.notInstalled }

        // Before launch, so a checkout installed by an earlier build gains the
        // route without the user reinstalling anything.
        try? writeMemoryProbe()

        port = Self.freePort() ?? 8188
        append("Starting ComfyUI on port \(port)…")

        let runner = ProcessRunner()
        serverRunner = runner
        let arguments = [mainScript.path, "--listen", "127.0.0.1", "--port", "\(port)"]
        let env = environment()
        let python = pythonURL
        let cwd = Self.rootURL

        // The server runs for the life of the app; its output is drained into the
        // install log so a startup failure is visible.
        serverTask = Task { [weak self] in
            do {
                let stream = await runner.lines(.init(executable: python, arguments: arguments,
                                                      environment: env, currentDirectory: cwd))
                for try await line in stream {
                    self?.append(line)
                }
            } catch {
                self?.append("ComfyUI server exited: \(error.localizedDescription)")
            }
            self?.isServerRunning = false
        }

        // Loading the frontend and scanning models takes a few seconds.
        for _ in 0..<60 {
            if await ping() { isServerRunning = true; return }
            try? await Task.sleep(for: .seconds(1))
        }
        throw ComfyError.serverDidNotStart
    }

    func stopServer() async {
        serverTask?.cancel()
        await serverRunner?.terminate()
        isServerRunning = false
    }

    /// The supervised server's pid, for memory reporting.
    var serverProcessIdentifier: pid_t? {
        get async { await serverRunner?.processIdentifier }
    }

    func ping() async -> Bool {
        var request = URLRequest(url: baseURL.appending(path: "system_stats"))
        request.timeoutInterval = 3
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    /// An unused local port, so two ComfyUI instances never collide.
    nonisolated static func freePort() -> Int? {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return nil }
        defer { close(socketFD) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { return nil }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketFD, $0, &length)
            }
        }
        guard named == 0 else { return nil }
        return Int(UInt16(bigEndian: address.sin_port))
    }

    /// Runs a setup command, draining its output into the install log.
    private func run(_ executable: URL, _ arguments: [String]) async throws {
        let runner = ProcessRunner()
        let stream = await runner.lines(.init(
            executable: executable, arguments: arguments, environment: environment()))
        for try await line in stream { append(line) }
    }

    /// Empties the log. It is a progress indicator, not an archive, so throwing
    /// it away is always safe; the next run starts a fresh one anyway.
    func clearLog() { installLog.removeAll() }

    private func append(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        installLog.append(trimmed)
        if installLog.count > 600 { installLog.removeFirst(installLog.count - 600) }
    }

    enum ComfyError: LocalizedError {
        case notInstalled, serverDidNotStart, uvMissing

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                "ComfyUI is not installed. Install it in Settings › ComfyUI."
            case .serverDidNotStart:
                "The ComfyUI server did not start. Check the log in Settings › ComfyUI."
            case .uvMissing:
                "uv is needed to build ComfyUI's Python environment. Install the MLX "
                + "runtime first, or `brew install uv`."
            }
        }
    }
}
