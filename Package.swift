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
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
