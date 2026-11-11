import Foundation

// The MCP face: an MCP server that puts Halation's local API in front of an
// agent.
//
// A proxy and nothing more: every tool here is one HTTP route, and the app
// remains the only thing that validates a spec, owns the queue or talks to an
// engine. Logic that lived in both places would eventually disagree, and the
// disagreement would surface as an agent being told it could do something the
// app then refused.
//
// Transport is stdio: newline-delimited JSON-RPC 2.0, one message per line.
// Anything written to stdout that is not a message corrupts the stream, so
// diagnostics go to stderr.

struct Tool {
    let name: String
    let description: String
    let schema: [String: Any]
    let writes: Bool
    let run: (Client, [String: Any]) -> APIResult
}

private func string(_ arguments: [String: Any], _ key: String) -> String {
    (arguments[key] as? String) ?? ""
}

private func objectSchema(_ properties: [String: Any], _ required: [String]) -> [String: Any] {
    ["type": "object", "properties": properties, "required": required]
}

/// What a render can be told, shared by estimate and submit so the two cannot
/// accept different things.
nonisolated(unsafe) private let renderProperties: [String: Any] = [
    "prompt": ["type": "string", "description": "What to generate."],
    "engine": ["type": "string", "enum": ["auto", "mlx", "comfyUI"],
               "description": "Leave out to let the app choose."],
    "seconds": ["type": "integer", "description": "Clip length, 5 to 15."],
    "steps": ["type": "integer", "description": "Denoising steps, 4 to 60."],
    "aspect": ["type": "string", "enum": ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"]],
    "resolution": ["type": "string", "enum": ["256", "384", "512", "640", "768", "1080", "1440"],
                   "description": """
                    Short edge in pixels. 768 is the model's native size. Below it is a \
                    preview: far faster and lighter, but a different canvas draws different \
                    noise, so even with the same seed it shows whether a prompt works, not \
                    what the 768 render will be. 1080 and 1440 render at 768 and upscale.
                    """],
    "cache": ["type": "string", "enum": ["off", "reuse", "easycache", "lazycache"],
              "description": """
                Reuse denoising steps that barely change: faster, less faithful. \
                'reuse' on MLX; 'easycache' or 'lazycache' on ComfyUI.
                """],
    "cache_threshold": ["type": "number",
                        "description": "0.05 to 0.5; higher reuses more. Default 0.2."],
]

// Never mutated after startup; read from one thread.
nonisolated(unsafe) let tools: [Tool] = [
    Tool(name: "halation_machine_capabilities",
         description: """
            How much memory this Mac has and which model/engine combinations fit in it. \
            Call this first: a render that does not fit will swap and take many times \
            longer, and nothing else will tell you that in advance. Each combination \
            comes back with a verdict of fits, tight or swaps.
            """,
         schema: objectSchema([:], []), writes: false) { client, _ in
             client.call(method: "GET", path: "/v1/machine")
         },

    Tool(name: "halation_estimate_render",
         description: """
            How long a render would take and whether it can start at all, without \
            queueing anything. Accepts the same arguments as halation_submit_render. \
            Returns an estimated time range, the engine that would run it, and any \
            blocking problems. Prefer this before submitting.
            """,
         schema: objectSchema(renderProperties, []), writes: false) { client, arguments in
             client.call(method: "POST", path: "/v1/estimate", body: arguments)
         },

    Tool(name: "halation_list_models",
         description: "The model catalogue and which entries are installed on this Mac.",
         schema: objectSchema([:], []), writes: false) { client, _ in
             client.call(method: "GET", path: "/v1/models")
         },

    Tool(name: "halation_list_library",
         description: """
            Finished renders, newest last, with prompt, seed, file path and the engine \
            that made each one. Use the id with halation_reproduce to render one again.
            """,
         schema: objectSchema([:], []), writes: false) { client, _ in
             client.call(method: "GET", path: "/v1/library")
         },

    Tool(name: "halation_get_library_item",
         description: "One finished render, including the full spec that produced it.",
         schema: objectSchema(
            ["id": ["type": "string", "description": "Library item id."]], ["id"]),
         writes: false) { client, arguments in
             client.call(method: "GET", path: "/v1/library/\(string(arguments, "id"))")
         },

    Tool(name: "halation_list_jobs",
         description: """
            The render queue: what is waiting, running or finished, with progress and \
            timings. This Mac renders one job at a time.
            """,
         schema: objectSchema([:], []), writes: false) { client, _ in
             client.call(method: "GET", path: "/v1/jobs")
         },

    Tool(name: "halation_get_job",
         description: """
            One job in detail, with its progress, timings and the tail of its log. \
            Report overall_progress (0 to 1, across every stage) and remaining_seconds; \
            `progress` restarts at each stage. Poll this rather than waiting: a full \
            render takes between twenty minutes and several hours; a preview, a few minutes.
            """,
         schema: objectSchema(
            ["id": ["type": "string", "description": "Job id."]], ["id"]),
         writes: false) { client, arguments in
             client.call(method: "GET", path: "/v1/jobs/\(string(arguments, "id"))")
         },

    Tool(name: "halation_submit_render",
         description: """
            Queue a render and return its job id immediately; it does not wait for the \
            render. **A full render takes between twenty minutes and several hours and \
            most of this Mac's memory**, and only one runs at a time, so submit \
            deliberately and poll halation_get_job rather than submitting again. To try \
            a prompt cheaply first, use resolution 384 with cache 'reuse'. Anything you \
            leave out is taken from whatever the app is currently set to. Reference \
            images cannot be supplied here.
            """,
         schema: objectSchema(renderProperties.merging([
            "seed": ["type": "integer",
                     "description": "Omit for a new result; set to repeat an old one."],
         ]) { $1 }, ["prompt"]), writes: true) { client, arguments in
             client.call(method: "POST", path: "/v1/renders", body: arguments)
         },

    Tool(name: "halation_reproduce",
         description: """
            Render a library item again with its original seed and settings — the same \
            clip, not a new one. This is how to iterate on a result: fetch the item, \
            change one thing, and submit. Costs the same time as the original render.
            """,
         schema: objectSchema(
            ["id": ["type": "string", "description": "Library item id."]], ["id"]),
         writes: true) { client, arguments in
             client.call(method: "POST",
                         path: "/v1/library/\(string(arguments, "id"))/reproduce")
         },

    Tool(name: "halation_cancel_job",
         description: "Stop a render that is queued or already running.",
         schema: objectSchema(
            ["id": ["type": "string", "description": "Job id."]], ["id"]),
         writes: true) { client, arguments in
             client.call(method: "POST", path: "/v1/jobs/\(string(arguments, "id"))/cancel")
         },
]

enum MCPServer {
    static func run(client: Client, version: String) -> Never {
        FileHandle.standardError.write(Data(
            "halation-mcp: ready, proxying \(client.connection.baseURL)\n".utf8))
        if client.connection.token.isEmpty {
            FileHandle.standardError.write(Data(
                "halation-mcp: no token found. Open Halation once and turn on the local API.\n".utf8))
        }
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            handle(message, client: client, version: version)
        }
        exit(0)
    }

    private static func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              var text = String(data: data, encoding: .utf8) else { return }
        text += "\n"
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    private static func reply(id: Any?, result: [String: Any]) {
        guard let id else { return }   // A notification expects no answer.
        send(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private static func reply(id: Any?, code: Int, message: String) {
        guard let id else { return }
        send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    /// A tool's answer. The app's JSON is passed through untouched, because the
    /// agent reading it is better served by the real shape than by a summary this
    /// process invented.
    private static func toolResult(_ result: APIResult) -> [String: Any] {
        ["content": [["type": "text", "text": result.body]], "isError": !result.isSuccess]
    }

    private static func handle(_ message: [String: Any], client: Client, version: String) {
        let id = message["id"]
        guard let method = message["method"] as? String else { return }

        switch method {
        case "initialize":
            let params = message["params"] as? [String: Any]
            // Echo the client's protocol version when it names one: this proxy has
            // no version-specific behaviour, and refusing over a version string
            // would be a failure for no reason.
            let protocolVersion = (params?["protocolVersion"] as? String) ?? "2025-06-18"
            reply(id: id, result: [
                "protocolVersion": protocolVersion,
                "capabilities": ["tools": [:] as [String: Any]],
                "serverInfo": ["name": "halation", "version": version],
                "instructions": """
                    Halation renders video locally on this Mac. A full render takes twenty \
                    minutes to several hours and only one runs at a time. Ask \
                    halation_machine_capabilities what fits before submitting anything, \
                    try prompts at resolution 384 first, and poll halation_get_job rather \
                    than waiting on a submit.
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
            let allowed = client.writesEnabled()
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
            reply(id: id, result: toolResult(tool.run(client, arguments)))

        default:
            reply(id: id, code: -32601, message: "Method \(method) is not supported.")
        }
    }
}
