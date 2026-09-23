import Foundation
import Network

/// A very small HTTP/1.1 server, bound to the loopback interface and nothing
/// else.
///
/// Hand-rolled rather than brought in: the app has no package dependencies, and
/// pulling in a full server stack to answer a dozen JSON routes on localhost
/// would be a large amount of code to audit for a small amount of surface. What
/// is here is deliberately the least that works — one request per connection,
/// no keep-alive, no chunked encoding, no TLS.
///
/// No TLS because there is nothing to protect in transit: the socket never
/// leaves the machine. What does the protecting is `requiredToken`, checked
/// before any route runs.
struct HTTPRequest: Sendable {
    var method: String
    var path: String
    /// Path with the query string removed, which is what routing matches on.
    var route: String
    var query: [String: String]
    var headers: [String: String]
    var body: Data

    var bearerToken: String? {
        guard let value = headers["authorization"],
              value.lowercased().hasPrefix("bearer ") else { return nil }
        return String(value.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    }
}

struct HTTPResponse: Sendable {
    var status: Int = 200
    var json: Data

    static func json(_ object: Any, status: Int = 200) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object,
                                                options: [.prettyPrinted, .sortedKeys]))
            ?? Data("{}".utf8)
        return HTTPResponse(status: status, json: data)
    }

    /// One shape for every failure, so a client can branch on `error` rather
    /// than on a status code it has to look up.
    static func error(_ status: Int, _ code: String, _ message: String) -> HTTPResponse {
        json(["error": code, "message": message], status: status)
    }
}

/// Runs the listener. Owned by `LocalAPIServer`, which supplies the routing.
final class HTTPServer: @unchecked Sendable {
    typealias Handler = @Sendable (HTTPRequest) async -> HTTPResponse

    private let queue = DispatchQueue(label: "halation.localapi", qos: .utility)
    private var listener: NWListener?
    private let handler: Handler

    /// Requests without this exact bearer token are refused before routing.
    private let requiredToken: String

    init(token: String, handler: @escaping Handler) {
        self.requiredToken = token
        self.handler = handler
    }

    func start(port: UInt16) throws {
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw APIError.badPort
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        // Bound to the loopback address itself, not merely restricted to the
        // loopback interface — and the port travels in the endpoint rather than
        // beside it. Measured, all three forms:
        //
        //     requiredLocalEndpoint + NWListener(using:on:)  throws EINVAL
        //     requiredLocalEndpoint + NWListener(using:)     127.0.0.1:8792
        //     NWListener(using:on:) alone                    *:8793
        //
        // The last is what this had, and `*` is a listening port on every
        // interface — not what the Automation page promises. The interface
        // restriction below filters connections as they arrive, but it does not
        // change what the socket binds.
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
        parameters.requiredInterfaceType = .loopback

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    enum APIError: LocalizedError {
        case badPort
        case portInUse(UInt16)

        var errorDescription: String? {
            switch self {
            case .badPort: "That is not a usable port number."
            case .portInUse(let port): "Port \(port) is already in use."
            }
        }
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    /// Reads until the headers are complete, then until `Content-Length` is
    /// satisfied. A request that never completes is dropped when the connection
    /// times out rather than being held open.
    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if error != nil {
                connection.cancel()
                return
            }

            guard let request = Self.parse(buffer) else {
                if isComplete {
                    connection.cancel()
                } else {
                    // Cap what an unauthenticated peer can make us hold.
                    if buffer.count > 4 * 1024 * 1024 {
                        connection.cancel()
                    } else {
                        self.receive(on: connection, buffer: buffer)
                    }
                }
                return
            }

            Task {
                let response: HTTPResponse
                if !Self.matches(request.bearerToken, self.requiredToken) {
                    response = .error(401, "unauthorized",
                                      "Send the token from Halation's Automation page as "
                                      + "`Authorization: Bearer <token>`.")
                } else {
                    response = await self.handler(request)
                }
                self.send(response, on: connection)
            }
        }
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        var head = "HTTP/1.1 \(response.status) \(Self.reason(response.status))\r\n"
        head += "Content-Type: application/json; charset=utf-8\r\n"
        head += "Content-Length: \(response.json.count)\r\n"
        // One request per connection: simpler than tracking keep-alive state,
        // and a polling client opens a socket every few seconds either way.
        head += "Connection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(response.json)
        connection.send(content: out, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 201: "Created"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 409: "Conflict"
        case 422: "Unprocessable Content"
        case 503: "Service Unavailable"
        default: "Error"
        }
    }

    /// Compares in time that does not depend on how much of the token matched.
    ///
    /// `==` on `String` returns at the first difference, and a caller on
    /// loopback can time a request precisely enough to walk a secret out of
    /// that, one byte at a time. The cost of not caring is small; the cost of
    /// being wrong is the whole token.
    private static func matches(_ offered: String?, _ expected: String) -> Bool {
        guard let offered else { return false }
        let a = Array(offered.utf8), b = Array(expected.utf8)
        // Length is not secret — it is fixed by us — so returning early on it
        // leaks nothing.
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices { difference |= a[index] ^ b[index] }
        return difference == 0
    }

    // MARK: - Parsing

    /// `nil` means "not a complete request yet", not "malformed": the caller
    /// keeps reading.
    static func parse(_ buffer: Data) -> HTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerEnd = buffer.range(of: separator) else { return nil }
        guard let headerText = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8)
        else { return nil }

        var lines = headerText.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let length = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerEnd.upperBound
        guard buffer.count - bodyStart >= length else { return nil }
        let body = buffer[bodyStart..<(bodyStart + length)]

        let target = String(requestLine[1])
        let parts = target.split(separator: "?", maxSplits: 1)
        var query: [String: String] = [:]
        if parts.count == 2 {
            for pair in parts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                guard let name = kv.first?.removingPercentEncoding else { continue }
                query[String(name)] = kv.count > 1
                    ? (kv[1].removingPercentEncoding ?? "") : ""
            }
        }

        return HTTPRequest(method: String(requestLine[0]).uppercased(),
                           path: target,
                           route: String(parts.first ?? ""),
                           query: query,
                           headers: headers,
                           body: Data(body))
    }
}
