import Foundation

/// A single queued render. Renders take hours, so a job is a durable record: it
/// survives quit, it can be resumed, and it carries its own log.
struct RenderJob: Codable, Sendable, Identifiable, Hashable {
    enum State: String, Codable, Sendable {
        case queued
        case preparing      // loading weights into memory
        case generating     // the diffusion loop
        case decoding       // VAE decode to frames
        case encoding       // our AVFoundation pass
        case finished
        case failed
        case cancelled

        var label: String {
            switch self {
            case .queued: "Queued"
            case .preparing: "Loading model"
            case .generating: "Generating"
            case .decoding: "Decoding"
            case .encoding: "Encoding"
            case .finished: "Finished"
            case .failed: "Failed"
            case .cancelled: "Cancelled"
            }
        }

        var isActive: Bool {
            switch self {
            case .preparing, .generating, .decoding, .encoding: true
            default: false
            }
        }

        var isTerminal: Bool {
            switch self {
            case .finished, .failed, .cancelled: true
            default: false
            }
        }

        var symbolName: String {
            switch self {
            case .queued: "clock"
            case .preparing: "arrow.down.circle"
            case .generating: "sparkles"
            case .decoding: "square.stack.3d.down.right"
            case .encoding: "film"
            case .finished: "checkmark.circle.fill"
            case .failed: "exclamationmark.triangle.fill"
            case .cancelled: "xmark.circle"
            }
        }
    }

    var id: UUID = UUID()
    var spec: GenerationSpec
    var state: State = .queued
    var createdAt: Date = .now
    var startedAt: Date?
    var finishedAt: Date?

    /// 0…1 within the current stage, as reported by the sidecar.
    var progress: Double = 0
    var completedSteps: Int = 0
    var totalSteps: Int = 0
    /// Seconds per diffusion step, averaged. The only reliable basis for an ETA.
    var secondsPerStep: Double?
    var peakMemoryBytes: Int64?

    var outputURL: URL?
    var sidecarAudioURL: URL?
    var thumbnailURL: URL?
    var failureMessage: String?
    /// The seed actually used, so a run is always reproducible after the fact.
    var resolvedSeed: Int64?

    var title: String {
        let trimmed = spec.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled render" }
        return String(trimmed.prefix(70))
    }

    var elapsed: TimeInterval? {
        guard let startedAt else { return nil }
        return (finishedAt ?? .now).timeIntervalSince(startedAt)
    }

    /// ETA derived from measured step time, not from a static guess.
    var estimatedRemaining: TimeInterval? {
        guard state == .generating, let secondsPerStep, totalSteps > 0 else { return nil }
        let remaining = max(0, totalSteps - completedSteps)
        return Double(remaining) * secondsPerStep
    }

    var overallProgress: Double {
        switch state {
        case .queued: 0
        case .preparing: 0.02
        case .generating: 0.05 + progress * 0.80
        case .decoding: 0.87
        case .encoding: 0.95
        case .finished: 1
        case .failed, .cancelled: progress
        }
    }
}

/// One line of structured output from the Python sidecar.
enum SidecarEvent: Sendable {
    case stage(RenderJob.State)
    case step(completed: Int, total: Int, secondsPerStep: Double?)
    case memory(bytes: Int64)
    case seed(Int64)
    case artifact(video: URL?, audio: URL?)
    case log(String)
    case failure(String)
    case downloadProgress(repoID: String, completed: Int64, total: Int64, file: String?)
    case finishedOK

    /// Parses one NDJSON line. Unrecognised lines become log entries rather than
    /// errors — the sidecar may print anything on stdout.
    static func parse(line: String) -> SidecarEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { return .log(trimmed) }

        func int64(_ key: String) -> Int64? {
            if let value = object[key] as? Int64 { return value }
            if let value = object[key] as? Int { return Int64(value) }
            if let value = object[key] as? Double { return Int64(value) }
            return nil
        }

        switch type {
        case "stage":
            guard let raw = object["stage"] as? String,
                  let state = RenderJob.State(rawValue: raw) else { return nil }
            return .stage(state)
        case "step":
            let completed = object["completed"] as? Int ?? 0
            let total = object["total"] as? Int ?? 0
            return .step(completed: completed, total: total,
                         secondsPerStep: object["seconds_per_step"] as? Double)
        case "memory":
            guard let bytes = int64("bytes") else { return nil }
            return .memory(bytes: bytes)
        case "seed":
            guard let seed = int64("seed") else { return nil }
            return .seed(seed)
        case "artifact":
            let video = (object["video"] as? String).map { URL(fileURLWithPath: $0) }
            let audio = (object["audio"] as? String).map { URL(fileURLWithPath: $0) }
            return .artifact(video: video, audio: audio)
        case "download":
            guard let repoID = object["repo_id"] as? String else { return nil }
            return .downloadProgress(repoID: repoID,
                                     completed: int64("completed") ?? 0,
                                     total: int64("total") ?? 0,
                                     file: object["file"] as? String)
        case "error":
            return .failure(object["message"] as? String ?? "Unknown sidecar error")
        case "done":
            return .finishedOK
        case "log":
            return .log(object["message"] as? String ?? "")
        default:
            return .log(trimmed)
        }
    }
}
