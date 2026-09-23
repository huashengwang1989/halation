import Foundation

// An MCP server that puts Halation's local API in front of an agent.
//
// A proxy and nothing more: every tool here is one HTTP route, and the app
// remains the only thing that validates a spec, owns the queue or talks to an
// engine. Logic that lived in both places would eventually disagree, and the
// disagreement would surface as an agent being told it could do something the
// app then refused.
//
// Shipped as a binary inside Halation.app rather than as a Node or Python
// script. An MCP client launches its servers itself, so a script means a
// runtime the machine may not have — and pointing at the app's own vendored
// Python would break for anyone who has not installed the render runtime yet.
// This has no dependencies and is built from the same checkout as the app.
//
// Transport is stdio: newline-delimited JSON-RPC 2.0, one message per line.
// Anything written to stdout that is not a message corrupts the stream, so
// diagnostics go to stderr.

// MARK: - Configuration

let environment = ProcessInfo.processInfo.environment
let baseURL = environment["HALATION_URL"] ?? "http://127.0.0.1:8765"
let token = environment["HALATION_TOKEN"] ?? ""

func log(_ message: String) {
    FileHandle.standardError.write(Data("halation-mcp: \(message)\n".utf8))
}

if token.isEmpty {
    log("HALATION_TOKEN is not set. Copy it from Halation's Automation page.")
}

// MARK: - The app's API

struct APIResult: Sendable {
    var status: Int
    var body: String
}

/// Carries the answer back out of the completion handler.
///
/// A plain captured `var` will not do under Swift 6 — the completion runs on
/// another thread, and the compiler is right that writing a local from there is
/// a data race. The lock makes the handoff explicit rather than assumed.
private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = APIResult(status: 0, body: "")

    func set(_ result: APIResult) {
        lock.lock(); defer { lock.unlock() }
        value = result
    }

    var result: APIResult {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

/// One call to the app. Synchronous on purpose: this process does nothing else
/// while a call is in flight, and a request/response loop that reads one line
/// at a time is easier to reason about than one that interleaves.
func callAPI(method: String, path: String, body: [String: Any]? = nil) -> APIResult {
    guard let url = URL(string: baseURL + path) else {
        return APIResult(status: 0, body: #"{"error":"bad_url"}"#)
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 15
    if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    }

    let box = ResultBox()
    let done = DispatchSemaphore(value: 0)
    let endpoint = baseURL
    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { done.signal() }
        if let error {
            // The overwhelmingly likely cause, worth saying rather than making
            // an agent guess from "connection refused".
            box.set(APIResult(status: 0, body: """
                {"error":"unreachable","message":"Could not reach Halation at \(endpoint). \
                Is the app running with the local API switched on? (\(error.localizedDescription))"}
                """))
            return
        }
        box.set(APIResult(status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          body: data.flatMap { String(data: $0, encoding: .utf8) } ?? ""))
    }.resume()
    done.wait()
    return box.result
}

/// Whether the app will currently accept work, so the tool list can reflect it.
func writesEnabled() -> Bool? {
    let health = callAPI(method: "GET", path: "/v1/health")
    guard health.status == 200,
          let data = health.body.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return object["writes_enabled"] as? Bool
}

// MARK: - Tools

struct Tool {
    let name: String
    let description: String
    let schema: [String: Any]
    let writes: Bool
    let run: ([String: Any]) -> APIResult
}

func string(_ arguments: [String: Any], _ key: String) -> String {
    (arguments[key] as? String) ?? ""
}

let objectSchema: ([String: Any], [String]) -> [String: Any] = { properties, required in
    ["type": "object", "properties": properties, "required": required]
}

// Descriptions are written for the thing that reads them. An agent decides
// which tool to call from these sentences alone, so each one says what it is
// for *and* what it costs — a render here is hours, not seconds.
let tools: [Tool] = [
    Tool(name: "halation_machine_capabilities",
         description: """
            How much memory this Mac has and which model/engine combinations fit in it. \
            Call this first: a render that does not fit will swap and take many times \
            longer, and nothing else will tell you that in advance. Each combination \
            comes back with a verdict of fits, tight or swaps.
            """,
         schema: objectSchema([:], []), writes: false) { _ in
             callAPI(method: "GET", path: "/v1/machine")
         },

    Tool(name: "halation_estimate_render",
         description: """
            How long a render would take and whether it can start at all, without \
            queueing anything. Accepts the same arguments as halation_submit_render. \
            Returns an estimated time range, the engine that would run it, and any \
            blocking problems. Prefer this before submitting.
            """,
         schema: objectSchema([
            "prompt": ["type": "string", "description": "What to generate."],
            "engine": ["type": "string", "enum": ["auto", "mlx", "comfyUI"],
                       "description": "Leave out to let the app choose."],
            "seconds": ["type": "integer", "description": "Clip length, 5 to 15."],
            "steps": ["type": "integer", "description": "Denoising steps, 4 to 60."],
            "aspect": ["type": "string",
                       "enum": ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"]],
         ], []), writes: false) { arguments in
             callAPI(method: "POST", path: "/v1/estimate", body: arguments)
         },

    Tool(name: "halation_list_models",
         description: "The model catalogue and which entries are installed on this Mac.",
         schema: objectSchema([:], []), writes: false) { _ in
             callAPI(method: "GET", path: "/v1/models")
         },

    Tool(name: "halation_list_library",
         description: """
            Finished renders, newest last, with prompt, seed, file path and the engine \
            that made each one. Use the id with halation_reproduce to render one again.
            """,
         schema: objectSchema([:], []), writes: false) { _ in
             callAPI(method: "GET", path: "/v1/library")
         },

    Tool(name: "halation_get_library_item",
         description: "One finished render, including the full spec that produced it.",
         schema: objectSchema(
            ["id": ["type": "string", "description": "Library item id."]], ["id"]),
         writes: false) { arguments in
             callAPI(method: "GET", path: "/v1/library/\(string(arguments, "id"))")
         },

    Tool(name: "halation_list_jobs",
         description: """
            The render queue: what is waiting, running or finished, with progress and \
            timings. This Mac renders one job at a time.
            """,
         schema: objectSchema([:], []), writes: false) { _ in
             callAPI(method: "GET", path: "/v1/jobs")
         },

    Tool(name: "halation_get_job",
         description: """
            One job in detail, with its progress, timings and the tail of its log. \
            Poll this rather than waiting: a render takes between twenty minutes and \
            several hours.
            """,
         schema: objectSchema(
            ["id": ["type": "string", "description": "Job id."]], ["id"]),
         writes: false) { arguments in
             callAPI(method: "GET", path: "/v1/jobs/\(string(arguments, "id"))")
         },

    Tool(name: "halation_submit_render",
         description: """
            Queue a render and return its job id immediately; it does not wait for the \
            render. **This takes between twenty minutes and several hours and most of \
            this Mac's memory**, and only one runs at a time, so submit deliberately \
            and poll halation_get_job rather than submitting again. Anything you leave \
            out is taken from whatever the app is currently set to. Reference images \
            cannot be supplied here.
            """,
         schema: objectSchema([
            "prompt": ["type": "string", "description": "What to generate."],
            "engine": ["type": "string", "enum": ["auto", "mlx", "comfyUI"]],
            "seconds": ["type": "integer", "description": "Clip length, 5 to 15."],
            "steps": ["type": "integer", "description": "Denoising steps, 4 to 60."],
            "aspect": ["type": "string",
                       "enum": ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"]],
            "seed": ["type": "integer",
                     "description": "Omit for a new result; set to repeat an old one."],
         ], ["prompt"]), writes: true) { arguments in
             callAPI(method: "POST", path: "/v1/renders", body: arguments)
         },

    Tool(name: "halation_reproduce",
         description: """
            Render a library item again with its original seed and settings — the same \
            clip, not a new one. This is how to iterate on a result: fetch the item, \
            change one thing, and submit. Costs the same hours as any other render.
            """,
         schema: objectSchema(
            ["id": ["type": "string", "description": "Library item id."]], ["id"]),
         writes: true) { arguments in
             callAPI(method: "POST",
                     path: "/v1/library/\(string(arguments, "id"))/reproduce")
         },

    Tool(name: "halation_cancel_job",
         description: "Stop a render that is queued or already running.",
         schema: objectSchema(
            ["id": ["type": "string", "description": "Job id."]], ["id"]),
         writes: true) { arguments in
             callAPI(method: "POST", path: "/v1/jobs/\(string(arguments, "id"))/cancel")
         },
]

// MARK: - JSON-RPC

func send(_ message: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: message),
          var text = String(data: data, encoding: .utf8) else { return }
    text += "\n"
    FileHandle.standardOutput.write(Data(text.utf8))
}

func reply(id: Any?, result: [String: Any]) {
    guard let id else { return }   // A notification expects no answer.
    send(["jsonrpc": "2.0", "id": id, "result": result])
}

func reply(id: Any?, code: Int, message: String) {
    guard let id else { return }
    send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
}

/// A tool's answer. The app's JSON is passed through untouched, because the
/// agent reading it is better served by the real shape than by a summary this
/// process invented.
func toolResult(_ result: APIResult) -> [String: Any] {
    let failed = !(200...299).contains(result.status)
    return [
        "content": [["type": "text", "text": result.body]],
        "isError": failed,
    ]
}

// Top-level code in a `main.swift` is main-actor isolated, and `tools` is
// declared there — so this is too. The process is single-threaded apart from
// the URLSession call, which hands its answer back through a lock.
@MainActor
func handle(_ message: [String: Any]) {
    let id = message["id"]
    guard let method = message["method"] as? String else { return }

    switch method {
    case "initialize":
        let params = message["params"] as? [String: Any]
        // Echo the client's protocol version when it names one: this proxy has
        // no version-specific behaviour, and refusing over a version string
        // would be a failure for no reason.
        let version = (params?["protocolVersion"] as? String) ?? "2025-06-18"
        reply(id: id, result: [
            "protocolVersion": version,
            "capabilities": ["tools": [:] as [String: Any]],
            "serverInfo": ["name": "halation", "version": "0.4.0"],
            "instructions": """
                Halation renders video locally on this Mac. Renders take twenty minutes \
                to several hours and only one runs at a time. Ask \
                halation_machine_capabilities what fits before submitting anything, and \
                poll halation_get_job rather than waiting on a submit.
                """,
        ])

    case "notifications/initialized", "notifications/cancelled":
        break   // Nothing to acknowledge.

    case "ping":
        reply(id: id, result: [:])

    case "tools/list":
        // Write tools are hidden while the app refuses writes, rather than
        // offered and then failing: a tool an agent cannot use is worse than
        // one it cannot see, because it will spend a turn discovering that.
        let allowed = writesEnabled()
        let visible = tools.filter { !$0.writes || (allowed ?? true) }
        reply(id: id, result: [
            "tools": visible.map { tool in
                ["name": tool.name, "description": tool.description,
                 "inputSchema": tool.schema] as [String: Any]
            },
        ])

    case "tools/call":
        let params = message["params"] as? [String: Any]
        let name = (params?["name"] as? String) ?? ""
        let arguments = (params?["arguments"] as? [String: Any]) ?? [:]
        guard let tool = tools.first(where: { $0.name == name }) else {
            reply(id: id, code: -32602, message: "No tool named \(name).")
            return
        }
        reply(id: id, result: toolResult(tool.run(arguments)))

    default:
        reply(id: id, code: -32601, message: "Method \(method) is not supported.")
    }
}

// MARK: - Loop

log("ready, proxying \(baseURL)")
while let line = readLine(strippingNewline: true) {
    guard !line.isEmpty,
          let data = line.data(using: .utf8),
          let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { continue }
    handle(message)
}
