import Foundation

/// Launches a subprocess and exposes its stdout as an `AsyncStream` of lines.
/// Renders run for hours, so cancellation and clean teardown matter more than speed.
actor ProcessRunner {
    struct Invocation: Sendable {
        var executable: URL
        var arguments: [String]
        var environment: [String: String] = [:]
        var currentDirectory: URL?
    }

    enum RunError: LocalizedError {
        case launchFailed(String)
        case exited(code: Int32, stderr: String)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let reason):
                "Could not start the helper process: \(reason)"
            case .exited(let code, let stderr):
                stderr.isEmpty
                    ? "The helper process exited with code \(code)."
                    : stderr
            }
        }
    }

    private var process: Process?

    /// Streams stdout lines. The stream finishes when the process exits; if the exit
    /// status is non-zero the final element is a `.failure` event carrying stderr.
    func lines(_ invocation: Invocation) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = invocation.executable
            process.arguments = invocation.arguments
            process.currentDirectoryURL = invocation.currentDirectory

            var environment = ProcessInfo.processInfo.environment
            for (key, value) in invocation.environment { environment[key] = value }
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // stderr is drained on a detached task so a chatty process can never
            // deadlock on a full pipe buffer.
            let stderrBuffer = StderrBuffer()
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                Task { await stderrBuffer.append(data) }
            }

            let lineBuffer = LineBuffer()
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                for line in lineBuffer.append(data) { continuation.yield(line) }
            }

            process.terminationHandler = { finished in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                // Flush any trailing partial line.
                if let line = lineBuffer.flush() { continuation.yield(line) }

                Task {
                    let stderr = await stderrBuffer.text()
                    if finished.terminationStatus == 0 || finished.terminationReason == .uncaughtSignal {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: RunError.exited(
                            code: finished.terminationStatus, stderr: stderr))
                    }
                }
            }

            continuation.onTermination = { _ in
                Task { await self.terminate() }
            }

            do {
                try process.run()
                self.process = process
            } catch {
                continuation.finish(throwing: RunError.launchFailed(error.localizedDescription))
            }
        }
    }

    /// Collects the whole of stdout. For short commands only.
    func capture(_ invocation: Invocation) async throws -> String {
        var output: [String] = []
        for try await line in lines(invocation) { output.append(line) }
        return output.joined(separator: "\n")
    }

    /// SIGTERM first so the sidecar can free Metal buffers, SIGKILL if it hangs.
    func terminate() {
        guard let process, process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(10)
        while process.isRunning, Date() < deadline {
            usleep(100_000)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }

    var isRunning: Bool { process?.isRunning ?? false }

    /// The child's pid, for attributing memory use to it.
    var processIdentifier: pid_t? {
        guard let process, process.isRunning else { return nil }
        return process.processIdentifier
    }
}

private actor StderrBuffer {
    private var data = Data()
    /// Keep only the tail; a failing render can emit megabytes of traceback.
    private let limit = 64 * 1024

    func append(_ chunk: Data) {
        data.append(chunk)
        if data.count > limit { data.removeFirst(data.count - limit) }
    }

    func text() -> String {
        String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

/// Splits an incoming byte stream into complete UTF-8 lines. `readabilityHandler`
/// fires on an arbitrary queue, so access is serialised behind a lock.
private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()

    func append(_ chunk: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(chunk)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = pending[pending.startIndex..<newline]
            pending.removeSubrange(pending.startIndex...newline)
            if let line = String(data: lineData, encoding: .utf8) { lines.append(line) }
        }
        return lines
    }

    func flush() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard !pending.isEmpty else { return nil }
        let line = String(data: pending, encoding: .utf8)
        pending.removeAll()
        return line
    }
}
