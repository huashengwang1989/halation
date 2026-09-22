import Foundation
import Observation

/// What the person did, as a machine-readable trail.
///
/// The problem it solves is narrow and real: the app gets operated while it is
/// being worked on — a language changed, a window resized, a file-access prompt
/// answered — and afterwards nobody can tell which changes were the build and
/// which were a click. A render log says what the engine did; nothing said what
/// the person did.
///
/// **Format: NDJSON, one event per line**, appended to
/// `Application Support/Halation/logs/interaction.ndjson`. Flat, one type per
/// field, short stable names — written to be read by a log pipeline rather than
/// by a person, on the assumption it will eventually be shipped somewhere that
/// indexes it.
///
/// ```json
/// {"ts":"2026-09-22 23:45:01+08:00","seq":12,"sid":"6F2A…","kind":"select",
///  "target":"settings.language","from":"en","to":"zh-Hans","screen":"settings"}
/// ```
///
/// | field    | meaning                                                      |
/// |----------|--------------------------------------------------------------|
/// | `ts`     | RFC 3339 with a space for the `T`, the app's own log format  |
/// | `seq`    | monotonic within a session; orders events inside one second   |
/// | `sid`    | one launch, so a single run can be isolated                   |
/// | `kind`   | `click`, `select`, `slide`, `edit`, `toggle`, `nav`, `life`   |
/// | `target` | stable dotted id, never a localized label                     |
/// | `from`/`to` | the change, for anything that has a before and an after    |
/// | `value`  | a payload that is not a change                                |
/// | `screen` | where it happened                                             |
///
/// Elasticsearch parses `ts` with
/// `"format": "yyyy-MM-dd HH:mm:ssXXX"`. The space instead of a `T` is RFC 3339
/// §5.6's own allowance, and matching the render logs is worth more here than
/// suiting a default parser.
///
/// **Never logs content.** A prompt is recorded as its length, not its text.
/// The question this answers is "what did they change", which length settles;
/// keeping the text would turn a debugging aid into a transcript of someone's
/// private work.
@MainActor
@Observable
final class InteractionLog {
    static let shared = InteractionLog()

    enum Kind: String, Sendable {
        /// A button.
        case click
        /// One of a fixed set: a picker, a segmented control, a menu item.
        case select
        /// A slider or stepper, recorded when it settles, not while it moves.
        case slide
        /// A text field, recorded when it gives up focus rather than per
        /// keystroke — a field logged per character would drown everything else.
        case edit
        /// A switch.
        case toggle
        /// Moving between sections, tabs or windows.
        case nav
        /// The app itself: launched, quit, became active.
        case life
    }

    struct Event: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let sequence: Int
        let session: String
        let kind: Kind
        let target: String
        let from: String?
        let to: String?
        let value: String?
        let screen: String?

        /// One NDJSON line. Absent fields are omitted rather than written null:
        /// an index is cheaper and queries read better when a field is either
        /// there or not.
        var line: String {
            var parts = [
                "\"ts\":\(Self.quote(RenderEngine.logTime.string(from: timestamp)))",
                "\"seq\":\(sequence)",
                "\"sid\":\(Self.quote(session))",
                "\"kind\":\(Self.quote(kind.rawValue))",
                "\"target\":\(Self.quote(target))",
            ]
            if let from { parts.append("\"from\":\(Self.quote(from))") }
            if let to { parts.append("\"to\":\(Self.quote(to))") }
            if let value { parts.append("\"value\":\(Self.quote(value))") }
            if let screen { parts.append("\"screen\":\(Self.quote(screen))") }
            return "{" + parts.joined(separator: ",") + "}"
        }

        private static func quote(_ text: String) -> String {
            let data = try? JSONSerialization.data(withJSONObject: [text])
            guard let data, let array = String(data: data, encoding: .utf8) else { return "\"\"" }
            // ["…"] -> "…", so escaping is JSONSerialization's problem and not
            // a hand-rolled table of cases that will miss one.
            return String(array.dropFirst().dropLast())
        }
    }

    /// The tail, for the Debug window. The file holds more.
    private(set) var recent: [Event] = []

    private let session = UUID().uuidString
    private var sequence = 0
    private var pending: [String] = []
    private var flushTask: Task<Void, Never>?

    /// Kept in memory for the window. Beyond this the file is the record.
    private let recentLimit = 2000
    /// The file is trimmed to its last half when it passes this.
    private let fileLimitBytes = 4 * 1024 * 1024

    nonisolated static var fileURL: URL {
        RenderEngine.logsDirectory.appending(path: "interaction.ndjson")
    }

    private init() {}

    // MARK: - Recording

    func record(_ kind: Kind, _ target: String,
                from: String? = nil, to: String? = nil,
                value: String? = nil, screen: String? = nil) {
        sequence += 1
        let event = Event(timestamp: .now, sequence: sequence, session: session,
                          kind: kind, target: target, from: from, to: to,
                          value: value, screen: screen ?? currentScreen)
        recent.append(event)
        if recent.count > recentLimit { recent.removeFirst(recent.count - recentLimit) }

        pending.append(event.line)
        scheduleFlush()
    }

    /// Records only when the value actually changed, which is most of what a
    /// picker or a slider reports.
    func recordChange(_ kind: Kind, _ target: String,
                      from: String, to: String, screen: String? = nil) {
        guard from != to else { return }
        record(kind, target, from: from, to: to, screen: screen)
    }

    /// Set by the root view so events carry where they happened without every
    /// call site having to say.
    var currentScreen: String?

    // MARK: - Writing

    /// Batched: a slider settling and a view appearing can produce several
    /// events in the same runloop turn, and one append per event would be a
    /// syscall each.
    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.flush()
        }
    }

    func flush() {
        flushTask = nil
        guard !pending.isEmpty else { return }
        let lines = pending.joined(separator: "\n") + "\n"
        pending.removeAll()
        let url = Self.fileURL
        let limit = fileLimitBytes
        Task.detached(priority: .utility) {
            Self.append(lines, to: url, trimmingPast: limit)
        }
    }

    nonisolated private static func append(_ text: String, to url: URL,
                                           trimmingPast limit: Int) {
        let fm = FileManager.default
        try? fm.createDirectory(at: RenderEngine.logsDirectory,
                                withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path) {
            try? Data(text.utf8).write(to: url, options: .atomic)
            return
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(text.utf8))
        }

        // Trim by whole lines from the front, so the file never grows without
        // bound and never ends up with half an event at the top.
        let attributes = try? fm.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard size > limit,
              let existing = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = existing.split(separator: "\n", omittingEmptySubsequences: true)
        let kept = lines.suffix(lines.count / 2).joined(separator: "\n") + "\n"
        try? Data(kept.utf8).write(to: url, options: .atomic)
    }

    // MARK: - Reading and clearing

    /// The file, newest last. Read on demand rather than held: the window is
    /// the only reader and it is opened rarely.
    nonisolated static func persistedLines() -> [String] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    func clear() {
        pending.removeAll()
        flushTask?.cancel()
        flushTask = nil
        recent.removeAll()
        let url = Self.fileURL
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
