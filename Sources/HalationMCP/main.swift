import Foundation

// One binary, two faces: Halation's MCP server and the `halation` command.
//
// Shipped inside Halation.app rather than as a Node or Python script. An MCP
// client launches its servers itself, so a script means a runtime the machine
// may not have — and pointing at the app's own vendored Python would break for
// anyone who has not installed the render runtime yet. This has no
// dependencies and is built from the same checkout as the app.
//
// Which face runs is decided by how it is started. An MCP client starts it with
// no arguments and talks over a pipe; a person types a command. The one case
// in between — no arguments, at a terminal — would otherwise sit silently
// waiting for JSON-RPC on stdin, which reads as a hang, so it prints help.
//
// The file is still called `halation-mcp`, so MCP configs written before the
// command existed keep working; the Automation page links it onto the PATH
// as `halation`.

let connection = Connection.discover()
let client = Client(connection)

/// The app's own version, so the server and the command report the release
/// they shipped in without a second number to keep in step.
let version: String = {
    guard let app = connection.appURL,
          let data = try? Data(contentsOf: app.appending(path: "Contents/Info.plist")),
          let info = try? PropertyListSerialization.propertyList(from: data, format: nil)
            as? [String: Any],
          let short = info["CFBundleShortVersionString"] as? String
    else { return "dev" }
    return short
}()

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.isEmpty {
    if isatty(STDIN_FILENO) != 0 {
        print(CLI.usage)
        exit(0)
    }
    MCPServer.run(client: client, version: version)
}

exit(CLI.run(arguments, client: client, version: version))
