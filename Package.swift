// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClaudeTopbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeTopbar",
            path: "Sources/ClaudeTopbar"
        )
    ]
)
