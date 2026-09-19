// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "VideoGen",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "VideoGen",
            path: "Sources/VideoGen",
            resources: [.copy("Resources/sidecar")],
            swiftSettings: [.swiftLanguageMode(.v6)],
            // SwiftUI's VideoPlayer lives in the _AVKit_SwiftUI overlay, whose
            // classes subclass AVKit's. Autolinking pulls in the overlay but not
            // AVKit itself, so instantiating the player aborted in
            // getSuperclassMetadata. Link it explicitly.
            linkerSettings: [.linkedFramework("AVKit")]
        )
    ]
)
