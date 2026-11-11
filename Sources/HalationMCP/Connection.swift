import Foundation

// How this binary finds the running app, and talks to it.
//
// Used by both faces of the binary — the MCP server and the `halation`
// command — so they cannot disagree about where the app is or what it said.

/// Where the app's API is, and how to authenticate to it.
///
/// Read from the app's own settings rather than handed in by whoever launched
/// this. An MCP config with a token pasted into it is one more copy of a secret
/// in a plain file, and one that goes stale the moment the token is
/// regenerated. Reading it here costs no protection: the token guards the port
/// against web pages and other users, and any program running as this user can
/// already read the settings file it lives in.
///
/// `HALATION_URL` and `HALATION_TOKEN` still win when set, so configs written
/// before this keep behaving exactly as they did.
struct Connection: Sendable {
    var baseURL: String
    var token: String
    /// The app bundle this binary sits inside, when it does.
    var appURL: URL?
    /// Whether the app has its API switched on, from its settings. `nil` when
    /// the settings could not be found at all.
    var apiEnabled: Bool?

    static func discover() -> Connection {
        let environment = ProcessInfo.processInfo.environment
        let app = enclosingApp()
        let domains = [app.flatMap(bundleIdentifier(of:)),
                       "com.huasheng.Halation", "com.local.halation"].compactMap { $0 }
        // The first domain that has ever held a token is the one in use.
        let domain = domains.first { preference("localAPIToken", in: $0) != nil }

        let port = domain.flatMap { preference("localAPIPort", in: $0) as? Int }
            .flatMap { $0 > 0 ? $0 : nil } ?? 8765
        let storedToken = domain.flatMap { preference("localAPIToken", in: $0) as? String }
        let enabled = domain.map { preference("localAPIEnabled", in: $0) as? Bool ?? false }

        return Connection(
            baseURL: environment["HALATION_URL"] ?? "http://127.0.0.1:\(port)",
            token: environment["HALATION_TOKEN"] ?? storedToken ?? "",
            appURL: app,
            apiEnabled: environment["HALATION_URL"] != nil ? true : enabled)
    }

    /// The `.app` this executable is inside, following the link that puts it
    /// on someone's PATH.
    private static func enclosingApp() -> URL? {
        var url = URL(fileURLWithPath: CommandLine.arguments[0])
        if !url.path.contains("/") || !FileManager.default.fileExists(atPath: url.path) {
            // Run by name from PATH: ask the system where the executable is.
            url = Bundle.main.executableURL ?? url
        }
        url = url.resolvingSymlinksInPath()
        while url.path != "/" {
            if url.pathExtension == "app" { return url }
            url = url.deletingLastPathComponent()
        }
        return nil
    }

    private static func bundleIdentifier(of app: URL) -> String? {
        let plist = app.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        else { return nil }
        return info["CFBundleIdentifier"] as? String
    }

    /// Another program's setting, by domain. `UserDefaults(suiteName:)` refuses
    /// a domain that is the caller's own bundle identifier — which this one is,
    /// when it runs from inside the app — so this goes underneath it.
    private static func preference(_ key: String, in domain: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }
}

// MARK: - Calls

struct APIResult: Sendable {
    var status: Int
    var body: String

    var isSuccess: Bool { (200...299).contains(status) }
    /// No answer at all: the app is not running, or its API is off.
    var isUnreachable: Bool { status == 0 }

    var object: [String: Any]? {
        body.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
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

final class Client: @unchecked Sendable {
    let connection: Connection
    private var launched = false

    init(_ connection: Connection) {
        self.connection = connection
    }

    /// One call to the app. Synchronous on purpose: neither face of this binary
    /// does anything else while a call is in flight.
    ///
    /// If the app is not answering but has its API switched on, it is opened —
    /// in the background, without taking focus — and the call tried again once
    /// it is up. It is never opened when the API is off: that switch is the
    /// user's consent to being driven, and opening the app would not flip it.
    func call(method: String, path: String, body: [String: Any]? = nil) -> APIResult {
        let first = send(method: method, path: path, body: body)
        guard first.isUnreachable, !launched, connection.apiEnabled == true,
              let app = connection.appURL else { return first }
        launched = true
        guard openInBackground(app) else { return first }

        // Loading the app and its model scan take a few seconds; the API
        // server starts as soon as the app is up.
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 1)
            if !send(method: "GET", path: "/v1/health", body: nil, timeout: 2).isUnreachable {
                return send(method: method, path: path, body: body)
            }
        }
        return first
    }

    private func openInBackground(_ app: URL) -> Bool {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-g", "-a", app.path]
        do {
            try open.run()
            open.waitUntilExit()
            return open.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func send(method: String, path: String, body: [String: Any]?,
                      timeout: TimeInterval = 15) -> APIResult {
        guard let url = URL(string: connection.baseURL + path) else {
            return APIResult(status: 0, body: #"{"error":"bad_url"}"#)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(connection.token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let box = ResultBox()
        let done = DispatchSemaphore(value: 0)
        let message = unreachableMessage
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { done.signal() }
            if let error {
                let detail = error.localizedDescription.replacingOccurrences(of: "\"", with: "'")
                box.set(APIResult(status: 0, body: """
                    {"error":"unreachable","message":"\(message) (\(detail))"}
                    """))
                return
            }
            box.set(APIResult(status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                              body: data.flatMap { String(data: $0, encoding: .utf8) } ?? ""))
        }.resume()
        done.wait()
        return box.result
    }

    /// Says which of the likely causes it is, where that is knowable, rather
    /// than leaving "connection refused" to be decoded.
    var unreachableMessage: String {
        switch connection.apiEnabled {
        case false?:
            return "Halation's local API is switched off. Open Halation, go to Automation, "
                + "and turn on the local API."
        case nil:
            return "Could not find Halation's settings on this Mac. Open Halation once, "
                + "then turn on the local API in Automation."
        case true?:
            return "Could not reach Halation at \(connection.baseURL). Is the app running?"
        }
    }

    /// Whether the app will currently accept work.
    func writesEnabled() -> Bool? {
        call(method: "GET", path: "/v1/health").object?["writes_enabled"] as? Bool
    }
}
