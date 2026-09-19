import Foundation
import Observation

/// Health report from the sidecar's `doctor` command.
struct RuntimeReport: Sendable, Equatable {
    var pythonVersion: String = ""
    var machine: String = ""
    var mlxMetalOK = false
    var ffmpegPath: String?
    var packages: [String: String] = [:]
    var problems: [String] = []
    var h3Usable = false
    var h3Module: String?
    var healthy = false

    static func parse(_ object: [String: Any]) -> RuntimeReport {
        var report = RuntimeReport()
        report.pythonVersion = object["python"] as? String ?? ""
        report.machine = object["machine"] as? String ?? ""
        report.mlxMetalOK = object["mlx_metal_ok"] as? Bool ?? false
        report.ffmpegPath = object["ffmpeg"] as? String
        report.problems = object["problems"] as? [String] ?? []
        report.healthy = object["healthy"] as? Bool ?? false
        if let packages = object["packages"] as? [String: Any] {
            report.packages = packages.compactMapValues { $0 as? String }
        }
        if let h3 = object["h3"] as? [String: Any] {
            report.h3Usable = h3["usable"] as? Bool ?? false
            report.h3Module = h3["module"] as? String
        }
        return report
    }
}

/// Creates and maintains the app's private Python environment.
///
/// Weights are shared (see `ModelStore`), but the *runtime* is not: it lives under
/// Application Support so it can be wiped and rebuilt without touching downloads,
/// and so it cannot be broken by changes to the user's own Python.
@MainActor
@Observable
final class RuntimeManager {
    enum Phase: Equatable, Sendable {
        case unknown
        case missing
        case installing(step: String, fraction: Double?)
        case ready(RuntimeReport)
        case failed(String)

        var isBusy: Bool { if case .installing = self { true } else { false } }
        var isReady: Bool { if case .ready(let report) = self { report.h3Usable } else { false } }
    }

    private(set) var phase: Phase = .unknown
    private(set) var installLog: [String] = []

    private let modelStore: ModelStore
    private var runner: ProcessRunner?

    init(modelStore: ModelStore) {
        self.modelStore = modelStore
    }

    // MARK: - Locations

    nonisolated static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return base.appending(path: "VideoGen", directoryHint: .isDirectory)
    }

    var venvURL: URL { Self.supportDirectory.appending(path: "runtime", directoryHint: .isDirectory) }
    var pythonURL: URL { venvURL.appending(path: "bin/python3") }
    var uvURL: URL { Self.supportDirectory.appending(path: "bin/uv") }

    /// The sidecar scripts, copied out of the app bundle so the interpreter can see
    /// them even when the bundle is read-only or translocated.
    var sidecarDirectory: URL { Self.supportDirectory.appending(path: "sidecar", directoryHint: .isDirectory) }
    var sidecarScript: URL { sidecarDirectory.appending(path: "videogen_sidecar.py") }

    var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: pythonURL.path)
    }

    /// Environment every sidecar invocation inherits. `HF_HOME` is the important
    /// one — it is what points Hugging Face downloads at the shared folder.
    func environment() -> [String: String] {
        var env: [String: String] = [
            "HF_HOME": modelStore.huggingFaceHome.path,
            // The hub's own tqdm bars would interleave with our NDJSON stream;
            // progress is measured from the cache directory instead.
            "HF_HUB_DISABLE_PROGRESS_BARS": "1",
            "PYTHONUNBUFFERED": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
            // MLX wants headroom to grow its buffer pool; the PyTorch fallback flag
            // is harmless here and helps if a dependency pulls torch in.
            "PYTORCH_ENABLE_MPS_FALLBACK": "1",
            "TOKENIZERS_PARALLELISM": "false",
            // The port is a checkout, not an installed package.
            "PYTHONPATH": portURL.path,
            "VIDEOGEN_H3_REPO": portURL.path,
        ]
        if let ffmpeg = Self.locateFFmpeg() { env["VIDEOGEN_FFMPEG"] = ffmpeg }
        // The port shells out to ffmpeg by name, so its directory must be on PATH.
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
        return env
    }

    nonisolated static func locateFFmpeg() -> String? {
        let fm = FileManager.default
        for candidate in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    // MARK: - Bootstrap

    func refresh() async {
        guard isInstalled else {
            phase = .missing
            return
        }
        await runDoctor()
    }

    func runDoctor() async {
        do {
            let runner = ProcessRunner()
            let output = try await runner.capture(.init(
                executable: pythonURL,
                arguments: [sidecarScript.path, "doctor"],
                environment: environment()))

            for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let data = String(line).data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      object["type"] as? String == "doctor"
                else { continue }
                let report = RuntimeReport.parse(object)
                phase = .ready(report)
                return
            }
            phase = .failed("The runtime check produced no report.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Full first-run install: fetch `uv`, create the venv, install requirements,
    /// then verify. Safe to re-run; `uv` skips work that is already done.
    func install(reinstall: Bool = false) async {
        installLog.removeAll()
        phase = .installing(step: "Preparing", fraction: 0)

        do {
            try FileManager.default.createDirectory(
                at: Self.supportDirectory, withIntermediateDirectories: true)
            try modelStore.ensureRootExists()
            try stageSidecar()

            if reinstall, FileManager.default.fileExists(atPath: venvURL.path) {
                append("Removing the previous runtime…")
                try FileManager.default.removeItem(at: venvURL)
            }

            phase = .installing(step: "Fetching uv", fraction: 0.1)
            let uv = try await ensureUV()

            phase = .installing(step: "Creating the Python environment", fraction: 0.25)
            try await run(uv, ["venv", venvURL.path, "--python", "3.12", "--seed"])

            phase = .installing(step: "Installing MLX", fraction: 0.4)
            let requirements = sidecarDirectory.appending(path: "requirements.txt")
            try await run(uv, ["pip", "install", "--python", pythonURL.path,
                               "--requirement", requirements.path])

            phase = .installing(step: "Fetching the MiniMax-H3 MLX port", fraction: 0.65)
            try await syncPort()

            phase = .installing(step: "Installing the port's own dependencies", fraction: 0.8)
            let portRequirements = portURL.appending(path: "requirements.txt")
            if FileManager.default.fileExists(atPath: portRequirements.path) {
                try await run(uv, ["pip", "install", "--python", pythonURL.path,
                                   "--requirement", portRequirements.path])
            }

            phase = .installing(step: "Verifying", fraction: 0.9)
            await runDoctor()

            if case .ready(let report) = phase, !report.healthy {
                append("Installed, but with warnings:")
                report.problems.forEach { append("  • \($0)") }
            }
        } catch {
            append("Install failed: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    /// Copies the bundled sidecar scripts into Application Support.
    private func stageSidecar() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: sidecarDirectory, withIntermediateDirectories: true)

        guard let source = Bundle.module.url(forResource: "sidecar", withExtension: nil) else {
            throw RuntimeError.missingResources
        }
        for file in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            let destination = sidecarDirectory.appending(path: file.lastPathComponent)
            if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            try fm.copyItem(at: file, to: destination)
        }
        append("Sidecar staged at \(sidecarDirectory.path)")
    }

    /// The MiniMax-H3 MLX port, cloned rather than pip-installed: the repository
    /// ships no `pyproject.toml`, so it is used from a checkout on `PYTHONPATH`.
    var portURL: URL {
        if let override = UserDefaults.standard.string(forKey: "h3RepoOverride"),
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return Self.supportDirectory.appending(path: "minimax-h3-mlx", directoryHint: .isDirectory)
    }

    static let portRepositoryURL = "https://github.com/PipeNetwork/minimax-h3-mlx.git"

    /// Clones the port, or fast-forwards an existing checkout.
    private func syncPort() async throws {
        let git = URL(fileURLWithPath: "/usr/bin/git")
        let fm = FileManager.default

        if fm.fileExists(atPath: portURL.appending(path: ".git").path) {
            append("Updating the existing checkout at \(portURL.path)")
            try await run(git, ["-C", portURL.path, "pull", "--ff-only"])
        } else {
            if fm.fileExists(atPath: portURL.path) { try fm.removeItem(at: portURL) }
            append("Cloning \(Self.portRepositoryURL)")
            try await run(git, ["clone", "--depth", "1",
                                Self.portRepositoryURL, portURL.path])
        }

        guard fm.fileExists(atPath: portURL.appending(path: "minimax_h3_mlx").path) else {
            throw RuntimeError.portMissing
        }
    }

    /// Prefers a `uv` already on the system; otherwise downloads the official
    /// standalone build into our own support directory.
    private func ensureUV() async throws -> URL {
        let fm = FileManager.default
        if fm.isExecutableFile(atPath: uvURL.path) { return uvURL }

        for candidate in ["/opt/homebrew/bin/uv", "/usr/local/bin/uv",
                          fm.homeDirectoryForCurrentUser.appending(path: ".cargo/bin/uv").path,
                          fm.homeDirectoryForCurrentUser.appending(path: ".local/bin/uv").path]
        where fm.isExecutableFile(atPath: candidate) {
            append("Using the uv already installed at \(candidate)")
            return URL(fileURLWithPath: candidate)
        }

        append("Downloading uv from astral.sh…")
        try fm.createDirectory(at: uvURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let archive = Self.supportDirectory.appending(path: "uv-download.tar.gz")
        try await run(URL(fileURLWithPath: "/usr/bin/curl"), [
            "--fail", "--location", "--silent", "--show-error",
            "--output", archive.path,
            "https://github.com/astral-sh/uv/releases/latest/download/uv-aarch64-apple-darwin.tar.gz",
        ])
        try await run(URL(fileURLWithPath: "/usr/bin/tar"), [
            "-xzf", archive.path,
            "-C", uvURL.deletingLastPathComponent().path,
            "--strip-components", "1",
        ])
        try? fm.removeItem(at: archive)

        guard fm.isExecutableFile(atPath: uvURL.path) else { throw RuntimeError.uvUnavailable }
        return uvURL
    }

    private func run(_ executable: URL, _ arguments: [String]) async throws {
        let runner = ProcessRunner()
        self.runner = runner
        let stream = await runner.lines(.init(
            executable: executable, arguments: arguments, environment: environment()))
        for try await line in stream {
            append(line)
        }
    }

    private func append(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        installLog.append(trimmed)
        // The log is a progress indicator, not an archive.
        if installLog.count > 600 { installLog.removeFirst(installLog.count - 600) }
    }

    enum RuntimeError: LocalizedError {
        case missingResources
        case uvUnavailable
        case portMissing

        var errorDescription: String? {
            switch self {
            case .missingResources:
                "The app bundle is missing its sidecar scripts. Reinstall the app."
            case .uvUnavailable:
                "Could not obtain uv, which is needed to build the Python environment. "
                + "Install it with `brew install uv` and try again."
            case .portMissing:
                "The MiniMax-H3 port was cloned but its Python package is missing. "
                + "Check the checkout path in Settings › Advanced."
            }
        }
    }
}
