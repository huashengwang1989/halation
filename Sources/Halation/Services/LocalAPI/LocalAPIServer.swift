import Foundation
import Observation

/// A local HTTP API, so another program — usually an agent — can ask this app
/// what the machine can do and hand it work.
///
/// **Off unless switched on, and loopback only.** An app that quietly opens a
/// port is an app people uninstall, and the thing behind this port can start an
/// eight-hour render that takes 120 GB of memory with it. So: a switch on the
/// Automation page, a token on every request, and reads and writes granted
/// separately — an agent that only needs to know whether a render will fit
/// should not also be able to queue one.
///
/// The app is the single owner of the queue and stays that way. This does not
/// write `queue.json` or spawn engines of its own; it calls the same
/// `RenderEngine` the buttons call, through the same validation. A second
/// writer would be the shortest path to two renders at once on a machine that
/// can barely hold one.
@MainActor
@Observable
final class LocalAPIServer {
    enum Status: Equatable {
        case off
        case running(port: UInt16)
        case failed(String)

        var isRunning: Bool { if case .running = self { true } else { false } }
    }

    private(set) var status: Status = .off
    /// Bumped on every answered request, so the page can show the thing is
    /// actually being used rather than merely switched on.
    private(set) var requestsServed = 0
    private(set) var lastRequest: (route: String, at: Date)?

    // MARK: - Settings

    /// Stored rather than chosen fresh each launch: an agent's configuration
    /// names a port, and a port that moved every launch would break it daily.
    var port: UInt16 {
        didSet {
            guard port != oldValue else { return }
            defaults.set(Int(port), forKey: Keys.port)
            if status.isRunning { restart() }
        }
    }

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Keys.enabled)
            InteractionLog.shared.record(.toggle, "api.enabled",
                                         value: isEnabled ? "on" : "off")
            if isEnabled { start() } else { stop() }
        }
    }

    /// Reads are the whole of the useful half and cannot cost anything. Writes
    /// queue work, so they are a separate decision.
    var allowsWrites: Bool {
        didSet {
            guard allowsWrites != oldValue else { return }
            defaults.set(allowsWrites, forKey: Keys.writes)
            InteractionLog.shared.record(.toggle, "api.writes",
                                         value: allowsWrites ? "on" : "off")
        }
    }

    /// How many jobs the API may leave waiting. An agent that cheerfully queues
    /// twenty eight-hour renders is the obvious way this goes wrong, and it
    /// would not look like a bug from the agent's side.
    var maxQueueDepth: Int {
        didSet {
            guard maxQueueDepth != oldValue else { return }
            defaults.set(maxQueueDepth, forKey: Keys.depth)
        }
    }

    private(set) var token: String

    private enum Keys {
        static let enabled = "localAPIEnabled"
        static let writes = "localAPIAllowsWrites"
        static let port = "localAPIPort"
        static let depth = "localAPIMaxQueueDepth"
        static let token = "localAPIToken"
    }

    private let defaults = UserDefaults.standard
    private var server: HTTPServer?
    private weak var app: AppState?

    init() {
        isEnabled = defaults.bool(forKey: Keys.enabled)
        allowsWrites = defaults.bool(forKey: Keys.writes)
        let storedPort = defaults.integer(forKey: Keys.port)
        port = storedPort > 0 ? UInt16(clamping: storedPort) : 8765
        let storedDepth = defaults.integer(forKey: Keys.depth)
        maxQueueDepth = storedDepth > 0 ? storedDepth : 3
        if let stored = defaults.string(forKey: Keys.token), !stored.isEmpty {
            token = stored
        } else {
            token = Self.freshToken()
            defaults.set(token, forKey: Keys.token)
        }
    }

    /// Called once, after `AppState` exists. The server reaches back into it
    /// for everything it answers, rather than keeping a second copy of the
    /// truth that could disagree with what is on screen.
    func attach(to app: AppState) {
        self.app = app
        if isEnabled { start() }
    }

    func regenerateToken() {
        token = Self.freshToken()
        defaults.set(token, forKey: Keys.token)
        InteractionLog.shared.record(.click, "api.regenerateToken")
        if status.isRunning { restart() }
    }

    private static func freshToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    var baseURL: String { "http://127.0.0.1:\(port)" }

    // MARK: - Lifecycle

    private func start() {
        stop()
        let server = HTTPServer(token: token) { [weak self] request in
            await self?.route(request) ?? .error(503, "unavailable", "Halation is shutting down.")
        }
        do {
            try server.start(port: port)
            self.server = server
            status = .running(port: port)
        } catch {
            self.server = nil
            // The common case by far is a port already taken, and the system's
            // own message for that is unhelpful.
            status = .failed("Could not listen on port \(port). "
                             + "Another program may already be using it.")
        }
    }

    private func stop() {
        server?.stop()
        server = nil
        status = .off
    }

    private func restart() {
        guard isEnabled else { return }
        start()
    }

    // MARK: - Routing

    private func route(_ request: HTTPRequest) async -> HTTPResponse {
        requestsServed += 1
        lastRequest = (request.route, .now)

        guard let app else {
            return .error(503, "unavailable", "Halation is still starting up.")
        }
        let routes = APIRoutes(app: app, server: self)

        switch (request.method, request.route) {
        case ("GET", "/v1/health"): return routes.health()
        case ("GET", "/v1/machine"): return routes.machine()
        case ("GET", "/v1/models"): return routes.models()
        case ("GET", "/v1/library"): return routes.library()
        case ("GET", "/v1/jobs"): return routes.jobs()
        case ("POST", "/v1/estimate"): return routes.estimate(body: request.body)

        case ("POST", "/v1/renders"):
            guard allowsWrites else { return Self.writesRefused }
            return routes.submit(body: request.body, maxQueueDepth: maxQueueDepth)

        default:
            break
        }

        // Paths carrying an id, matched after the fixed ones. Written out
        // rather than pattern-matched on the array: Swift does not destructure
        // arrays in patterns, and a regex here would be harder to read than
        // four comparisons.
        let parts = request.route.split(separator: "/").map(String.init)
        if request.method == "GET", parts.count == 3, parts[0] == "v1" {
            if parts[1] == "library" { return routes.libraryItem(id: parts[2]) }
            if parts[1] == "jobs" { return routes.job(id: parts[2]) }
        }
        if request.method == "POST", parts.count == 4, parts[0] == "v1" {
            guard allowsWrites else { return Self.writesRefused }
            if parts[1] == "jobs", parts[3] == "cancel" {
                return routes.cancel(id: parts[2])
            }
            if parts[1] == "library", parts[3] == "reproduce" {
                return routes.reproduce(id: parts[2], maxQueueDepth: maxQueueDepth)
            }
        }
        return .error(404, "no_such_route",
                      "\(request.method) \(request.route) is not a route. "
                      + "GET /v1/health lists what is.")
    }

    private static let writesRefused = HTTPResponse.error(
        403, "writes_disabled",
        "This API is read-only. Turn on \"Allow queueing renders\" on Halation's "
        + "Automation page to let it accept work.")
}
