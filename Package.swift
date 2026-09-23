// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Halation",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Halation",
            path: "Sources/Halation",
            resources: [.copy("Resources/sidecar"), .process("Resources/Localizations"),
                        .copy("Resources/translation-catalog.json")],
            swiftSettings: [.swiftLanguageMode(.v6)],
            // SwiftUI's VideoPlayer lives in the _AVKit_SwiftUI overlay, whose
            // classes subclass AVKit's. Autolinking pulls in the overlay but not
            // AVKit itself, so instantiating the player aborted in
            // getSuperclassMetadata. Link it explicitly.
            linkerSettings: [.linkedFramework("AVKit")]
        ),
        // The MCP server, shipped inside the app bundle. Its own executable and
        // no shared code: it is a proxy over the local API's HTTP routes, and
        // anything it knew about specs or the queue would be a second copy of a
        // rule that the app already owns.
        .executableTarget(
            name: "halation-mcp",
            path: "Sources/HalationMCP",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
