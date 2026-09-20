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
            resources: [.copy("Resources/sidecar"), .process("Resources/Localizations")],
            swiftSettings: [.swiftLanguageMode(.v6)],
            // SwiftUI's VideoPlayer lives in the _AVKit_SwiftUI overlay, whose
            // classes subclass AVKit's. Autolinking pulls in the overlay but not
            // AVKit itself, so instantiating the player aborted in
            // getSuperclassMetadata. Link it explicitly.
            linkerSettings: [.linkedFramework("AVKit")]
        )
    ]
)
