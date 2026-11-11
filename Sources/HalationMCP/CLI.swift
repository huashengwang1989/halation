import Foundation

// The `halation` command: the same API as the MCP tools, for a terminal or a
// script.
//
// Plain text by default, laid out for reading; `--json` passes the app's own
// JSON through untouched for anything that wants to parse it. Ids can be
// shortened to any unambiguous prefix, which is what makes them usable by hand.
//
// Exit codes: 0 done, 1 the app said no or the render failed, 2 a usage
// mistake, 3 the app could not be reached.

enum CLI {
    static let usage = """
        halation — drive Halation from a terminal or a script.

        usage: halation <command> [options]

        Rendering
          render "<prompt>" [options] [--wait]   queue a render; prints its job id
          estimate "<prompt>" [options]          how long it would take, and whether it can start
          reproduce <library-id> [--wait]        render a finished clip again, same seed and settings
          wait <job-id>                          follow a job until it finishes
          cancel <job-id>                        stop a queued or running job

        Looking
          status [job-id]                        the queue, or one job in detail
          library [--limit N]                    finished clips, newest first
          show <library-id>                      one clip and the spec that made it
          machine                                memory, and which models fit
          models                                 the model catalogue and what is installed

        Render options
          --seconds N          clip length, 5–15
          --steps N            denoising steps, 4–60
          --aspect R           21:9 16:9 4:3 1:1 3:4 9:16
          --resolution P       256 384 512 640 768 1080 1440 (768 is native; below is a preview)
          --engine E           auto mlx comfyUI
          --seed N             repeat a result exactly
          --cache C            off reuse easycache lazycache
          --threshold T        step-reuse threshold, 0.05–0.5
          Anything left out is taken from how the app's Compose screen is set.

        Everywhere
          --json               print the app's JSON instead of text
          --version            print the version

        Ids can be shortened to their first few characters.
        Halation must be installed with its local API switched on (Automation page);
        if the app is not running, it is opened in the background.
        Run with no arguments from an MCP client, this is Halation's MCP server.
        """

    // MARK: - Entry

    static func run(_ arguments: [String], client: Client, version: String) -> Int32 {
        var parsed = Arguments(arguments)
        let json = parsed.flag("--json")

        guard let command = parsed.next() else {
            print(usage)
            return 0
        }

        let options: Options
        do { options = try Options(parsing: &parsed) } catch {
            return fail("\(error)", code: 2)
        }

        let context = Context(client: client, json: json)
        switch command {
        case "help", "--help", "-h":
            print(usage); return 0
        case "--version", "version":
            print("halation \(version)"); return 0
        case "render":
            guard let prompt = parsed.next() else { return fail("render needs a prompt.", code: 2) }
            return context.submit(path: "/v1/renders",
                                  body: options.body(prompt: prompt), wait: options.wait)
        case "estimate":
            guard let prompt = parsed.next() else { return fail("estimate needs a prompt.", code: 2) }
            return context.estimate(options.body(prompt: prompt))
        case "reproduce":
            guard let id = parsed.next() else { return fail("reproduce needs a library id.", code: 2) }
            guard let full = context.resolve(id, in: .library) else { return 1 }
            return context.submit(path: "/v1/library/\(full)/reproduce", body: nil, wait: options.wait)
        case "wait":
            guard let id = parsed.next() else { return fail("wait needs a job id.", code: 2) }
            guard let full = context.resolve(id, in: .jobs) else { return 1 }
            return context.follow(full)
        case "cancel":
            guard let id = parsed.next() else { return fail("cancel needs a job id.", code: 2) }
            guard let full = context.resolve(id, in: .jobs) else { return 1 }
            return context.simple(method: "POST", path: "/v1/jobs/\(full)/cancel") { _ in
                "Cancelling \(short(full))."
            }
        case "status", "jobs", "queue":
            if let id = parsed.next() {
                guard let full = context.resolve(id, in: .jobs) else { return 1 }
                return context.simple(method: "GET", path: "/v1/jobs/\(full)", render: Text.job)
            }
            return context.simple(method: "GET", path: "/v1/jobs", render: Text.jobs)
        case "library":
            return context.simple(method: "GET", path: "/v1/library") {
                Text.library($0, limit: options.limit)
            }
        case "show":
            guard let id = parsed.next() else { return fail("show needs a library id.", code: 2) }
            guard let full = context.resolve(id, in: .library) else { return 1 }
            return context.simple(method: "GET", path: "/v1/library/\(full)", render: Text.item)
        case "machine":
            return context.simple(method: "GET", path: "/v1/machine", render: Text.machine)
        case "models":
            return context.simple(method: "GET", path: "/v1/models", render: Text.models)
        case "mcp":
            MCPServer.run(client: client, version: version)
        default:
            return fail("Unknown command \(command). Run halation help.", code: 2)
        }
    }

    @discardableResult
    static func fail(_ message: String, code: Int32) -> Int32 {
        FileHandle.standardError.write(Data("halation: \(message)\n".utf8))
        return code
    }
}

// MARK: - Arguments

/// Positional arguments in order, with flags pulled out wherever they appear.
struct Arguments {
    private var items: [String]

    init(_ items: [String]) { self.items = items }

    mutating func flag(_ name: String) -> Bool {
        guard let index = items.firstIndex(of: name) else { return false }
        items.remove(at: index)
        return true
    }

    mutating func value(_ name: String) throws -> String? {
        guard let index = items.firstIndex(of: name) else { return nil }
        guard index + 1 < items.count else { throw UsageError("\(name) needs a value.") }
        let value = items[index + 1]
        items.removeSubrange(index...(index + 1))
        return value
    }

    mutating func next() -> String? {
        items.isEmpty ? nil : items.removeFirst()
    }
}

struct UsageError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// The render options, as the API names them.
struct Options {
    var fields: [String: Any] = [:]
    var wait = false
    var limit = 20

    init(parsing arguments: inout Arguments) throws {
        wait = arguments.flag("--wait")
        func integer(_ flag: String, _ key: String) throws {
            guard let raw = try arguments.value(flag) else { return }
            guard let value = Int(raw) else { throw UsageError("\(flag) takes a whole number.") }
            fields[key] = value
        }
        try integer("--seconds", "seconds")
        try integer("--steps", "steps")
        try integer("--seed", "seed")
        for (flag, key) in [("--aspect", "aspect"), ("--resolution", "resolution"),
                            ("--engine", "engine"), ("--cache", "cache")] {
            if let value = try arguments.value(flag) { fields[key] = value }
        }
        if let raw = try arguments.value("--threshold") {
            guard let value = Double(raw) else { throw UsageError("--threshold takes a number.") }
            fields["cache_threshold"] = value
        }
        if let raw = try arguments.value("--limit") {
            guard let value = Int(raw), value > 0 else { throw UsageError("--limit takes a positive number.") }
            limit = value
        }
    }

    func body(prompt: String) -> [String: Any] {
        fields.merging(["prompt": prompt]) { $1 }
    }
}

// MARK: - Running commands

private func short(_ id: String) -> String { String(id.prefix(8)) }

struct Context {
    let client: Client
    let json: Bool

    enum Collection { case jobs, library }

    /// A full id from any unambiguous prefix of one.
    func resolve(_ prefix: String, in collection: Collection) -> String? {
        let (path, key) = collection == .jobs ? ("/v1/jobs", "jobs") : ("/v1/library", "items")
        let result = client.call(method: "GET", path: path)
        guard check(result) else { return nil }
        let ids = (result.object?[key] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        let matches = ids.filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
        switch matches.count {
        case 1: return matches[0]
        case 0:
            CLI.fail("No \(collection == .jobs ? "job" : "library item") starts with \(prefix).", code: 1)
        default:
            CLI.fail("\(prefix) matches \(matches.count) ids; give a few more characters.", code: 1)
        }
        return nil
    }

    /// One call, printed as text or as the app's JSON.
    func simple(method: String, path: String,
                render: ([String: Any]) -> String) -> Int32 {
        let result = client.call(method: method, path: path)
        guard check(result) else { return result.isUnreachable ? 3 : 1 }
        if json { print(result.body) } else { print(render(result.object ?? [:])) }
        return 0
    }

    func estimate(_ body: [String: Any]) -> Int32 {
        let result = client.call(method: "POST", path: "/v1/estimate", body: body)
        guard check(result) else { return result.isUnreachable ? 3 : 1 }
        if json { print(result.body); return 0 }
        let object = result.object ?? [:]
        print(Text.estimate(object))
        return (object["can_submit"] as? Bool) == false ? 1 : 0
    }

    func submit(path: String, body: [String: Any]?, wait: Bool) -> Int32 {
        let result = client.call(method: "POST", path: path, body: body)
        guard check(result) else { return result.isUnreachable ? 3 : 1 }
        let object = result.object ?? [:]
        guard let id = object["id"] as? String else { print(result.body); return 1 }
        if json && !wait { print(result.body); return 0 }
        if !json {
            let behind = object["queued_behind"] as? Int ?? 0
            print("Queued \(short(id))" + (behind > 0 ? ", behind \(behind) job(s)." : "."))
        }
        return wait ? follow(id) : 0
    }

    /// Polls a job until it ends, drawing one updating line on a terminal and a
    /// line per change of state otherwise, so a log file stays readable.
    func follow(_ id: String) -> Int32 {
        let interactive = isatty(STDOUT_FILENO) != 0
        var lastLine = ""
        var lastState = ""
        var lastDecile = -1
        while true {
            let result = client.call(method: "GET", path: "/v1/jobs/\(id)")
            guard check(result) else { return result.isUnreachable ? 3 : 1 }
            let job = result.object ?? [:]
            let state = job["state"] as? String ?? "?"

            if ["finished", "failed", "cancelled"].contains(state) {
                if interactive && !lastLine.isEmpty { print("") }
                if json { print(result.body) } else { print(Text.ending(job)) }
                return state == "finished" ? 0 : 1
            }

            if interactive {
                let line = Text.progressLine(job, width: terminalWidth())
                // Pad to the old length so a shorter line leaves no tail behind.
                let padded = line.padding(toLength: max(line.count, lastLine.count),
                                          withPad: " ", startingAt: 0)
                FileHandle.standardOutput.write(Data("\r\(padded)".utf8))
                lastLine = line
            } else {
                // A log gets a line per stage and per tenth of the way, not one
                // every poll: readable afterwards, and still shows it is moving.
                let decile = Int(((job["overall_progress"] as? Double) ?? 0) * 10)
                if state != lastState || decile != lastDecile {
                    print(Text.progressLine(job, bar: false))
                    lastDecile = decile
                }
            }
            lastState = state
            Thread.sleep(forTimeInterval: interactive ? 2 : 10)
        }
    }

    /// Columns in the terminal, so the progress line never wraps.
    private func terminalWidth() -> Int? {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0 else { return nil }
        return Int(size.ws_col)
    }

    /// Reports a failed call on stderr. True when the call succeeded.
    func check(_ result: APIResult) -> Bool {
        if result.isSuccess { return true }
        let object = result.object
        var message = object?["message"] as? String ?? "HTTP \(result.status): \(result.body)"
        if let blocking = object?["blocking"] as? [String], !blocking.isEmpty {
            message += "\n" + blocking.map { "  • \($0)" }.joined(separator: "\n")
        }
        CLI.fail(message, code: 1)
        return false
    }
}

// MARK: - Text output

enum Text {
    static func jobs(_ object: [String: Any]) -> String {
        let jobs = object["jobs"] as? [[String: Any]] ?? []
        guard !jobs.isEmpty else { return "The queue is empty." }
        // Newest first, as the app's Queue page shows them.
        return jobs.reversed().map { job in
            let state = (job["state"] as? String ?? "?").padding(toLength: 10, withPad: " ", startingAt: 0)
            let progress = (job["overall_progress"] as? Double) ?? (job["progress"] as? Double ?? 0)
            let percent = String(format: "%3.0f%%", progress * 100)
            return "\(short(job["id"] as? String ?? ""))  \(state) \(percent)  \(oneLine(job["prompt"]))"
        }.joined(separator: "\n")
    }

    static func job(_ job: [String: Any]) -> String {
        var lines = [
            "Job      \(job["id"] as? String ?? "")",
            "Progress \(progressLine(job, bar: true))",
            "Prompt   \(oneLine(job["prompt"], width: 200))",
            "Engine   \(job["engine"] as? String ?? "?")",
        ]
        if let seed = job["seed"] as? Int { lines.append("Seed     \(seed)") }
        if let path = job["output_path"] as? String { lines.append("Output   \(path)") }
        if let failure = job["failure"] as? String { lines.append("Failure  \(failure)") }
        return lines.joined(separator: "\n")
    }

    /// One line for a job in flight, e.g.
    ///
    ///     3f9a2c1d [██████░░░░░░░░░░]  41%  generating · step 12/30 · about 14m left · 9m in
    ///
    /// The bar follows the app's overall progress rather than the per-stage
    /// figure, which drops back to zero at every stage and would make the bar
    /// run backwards. Loading the model has no steps, so it shows what is being
    /// loaded instead. `width` is the terminal's, so the line can be cut to fit:
    /// one that wraps cannot be redrawn in place.
    static func progressLine(_ job: [String: Any], width: Int? = nil, bar: Bool = true) -> String {
        let state = job["state"] as? String ?? "?"
        let overall = min(1, max(0, (job["overall_progress"] as? Double) ?? (job["progress"] as? Double ?? 0)))
        let done = job["completed_steps"] as? Int ?? 0
        let total = job["total_steps"] as? Int ?? 0

        var detail: String?
        if state == "preparing", let text = job["stage_detail"] as? String, !text.isEmpty {
            detail = text
        }
        var step: String?
        if state == "generating", total > 0 { step = "step \(done)/\(total)" }
        var left: String?
        if let seconds = job["remaining_seconds"] as? Double, seconds > 0 {
            left = "about \(duration(seconds)) left"
        } else if state == "generating", let perStep = job["seconds_per_step"] as? Double,
                  perStep > 0, total > done {
            left = "about \(duration(perStep * Double(total - done))) left"
        }
        var elapsed: String?
        if let seconds = job["elapsed_seconds"] as? Double, seconds >= 60 {
            elapsed = "\(duration(seconds)) in"
        }
        var cells = bar && state != "queued" ? 20 : 0

        func compose() -> String {
            let phaseText = phase(state) + (detail.map { " (\($0))" } ?? "")
            let text = [phaseText, step, left, elapsed].compactMap { $0 }.joined(separator: " · ")
            var line = short(job["id"] as? String ?? "") + " "
            if cells > 0 { line += progressBar(overall, cells: cells) + " " }
            if state != "queued" { line += String(format: "%3.0f%%", overall * 100) + "  " }
            return line + text
        }

        // Too wide for the terminal, the least useful parts go first, so the
        // time left survives longest. A line that wraps cannot be redrawn in place.
        guard let width, width > 10 else { return compose() }
        let fits = { compose().count <= width - 1 }
        if !fits() { elapsed = nil }
        if !fits() { detail = nil }
        if !fits() && cells > 0 { cells = 10 }
        if !fits() { step = nil }
        if !fits() { cells = 0 }
        let line = compose()
        return line.count <= width - 1 ? line : String(line.prefix(width - 2)) + "…"
    }

    static func column(_ value: Any?, _ width: Int) -> String {
        (value as? String ?? "").padding(toLength: width, withPad: " ", startingAt: 0)
    }

    static func progressBar(_ fraction: Double, cells: Int = 20) -> String {
        let filled = Int((fraction * Double(cells)).rounded(.down))
        return "[" + String(repeating: "█", count: filled)
            + String(repeating: "░", count: cells - filled) + "]"
    }

    /// The app's state names describe the job; these describe what the Mac is
    /// doing, which is what someone watching a terminal wants to know.
    static func phase(_ state: String) -> String {
        switch state {
        case "queued": "waiting in the queue"
        case "preparing": "loading the model"
        case "generating": "generating"
        case "decoding": "decoding frames"
        case "encoding": "writing the video"
        case "cancelling": "cancelling"
        default: state
        }
    }

    static func ending(_ job: [String: Any]) -> String {
        let state = job["state"] as? String ?? "?"
        switch state {
        case "finished":
            return "Finished: \(job["output_path"] as? String ?? "(no file)")"
        case "failed":
            return "Failed: \(job["failure"] as? String ?? "no reason given")"
        default:
            return "Cancelled."
        }
    }

    static func library(_ object: [String: Any], limit: Int) -> String {
        let items = (object["items"] as? [[String: Any]] ?? []).reversed().prefix(limit)
        guard !items.isEmpty else { return "No finished clips yet." }
        return items.map { item in
            let date = (item["created_at"] as? String).map { String($0.prefix(10)) } ?? "          "
            let missing = (item["exists"] as? Bool) == false ? "  (file missing)" : ""
            return "\(short(item["id"] as? String ?? ""))  \(date)  \(oneLine(item["prompt"]))\(missing)"
        }.joined(separator: "\n")
    }

    static func item(_ item: [String: Any]) -> String {
        var lines = [
            "Clip     \(item["id"] as? String ?? "")",
            "Prompt   \(oneLine(item["prompt"], width: 200))",
            "File     \(item["path"] as? String ?? "?")",
            "Engine   \(item["engine"] as? String ?? "?")   Mode \(item["mode"] as? String ?? "?")",
        ]
        if let seed = item["seed"] as? Int { lines.append("Seed     \(seed)") }
        if let seconds = item["render_seconds"] as? Double {
            lines.append("Took     \(duration(seconds))")
        }
        return lines.joined(separator: "\n")
    }

    static func estimate(_ object: [String: Any]) -> String {
        var lines: [String] = []
        if let range = object["estimated_seconds"] as? [String: Any],
           let low = range["low"] as? Int, let high = range["high"] as? Int {
            lines.append("About \(duration(Double(low))) – \(duration(Double(high)))")
        }
        lines.append("Engine \(object["engine"] as? String ?? "?"), "
                     + "\(object["generates_at"] as? String ?? "?"), "
                     + "\(object["frames"] as? Int ?? 0) frames")
        for message in object["blocking"] as? [String] ?? [] { lines.append("Cannot start: \(message)") }
        for message in object["advisories"] as? [String] ?? [] { lines.append("Note: \(message)") }
        return lines.joined(separator: "\n")
    }

    static func machine(_ object: [String: Any]) -> String {
        var lines = ["Memory  \(gigabytes(object["installed_memory_bytes"]))"]
        for row in object["combinations"] as? [[String: Any]] ?? [] {
            let verdict = (row["verdict"] as? String ?? "?").padding(toLength: 7, withPad: " ", startingAt: 0)
            lines.append("  \(verdict) \(gigabytes(row["expected_peak_bytes"])) peak  \(row["label"] as? String ?? "")")
        }
        return lines.joined(separator: "\n")
    }

    static func models(_ object: [String: Any]) -> String {
        let models = object["models"] as? [[String: Any]] ?? []
        return models.map { model in
            let mark = (model["installed"] as? Bool) == true ? "✓" : " "
            let role = column(model["role"], 12)
            let quantization = column(model["quantization"], 12)
            let size = gigabytes(model["download_bytes"])
            return "\(mark) \(role)\(quantization)\(size)  \(model["repo"] as? String ?? "")"
        }.joined(separator: "\n")
    }

    // MARK: Pieces

    private static func oneLine(_ value: Any?, width: Int = 60) -> String {
        let text = (value as? String ?? "").replacingOccurrences(of: "\n", with: " ")
        return text.count > width ? String(text.prefix(width - 1)) + "…" : text
    }

    private static func gigabytes(_ value: Any?) -> String {
        let bytes = (value as? Double) ?? (value as? Int).map(Double.init) ?? 0
        return String(format: "%5.1f GB", bytes / 1e9)
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 90 { return "\(total) s" }
        let minutes = total / 60
        if minutes < 90 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}
