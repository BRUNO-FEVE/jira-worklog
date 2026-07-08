// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorklogBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "WorklogBar", path: "Sources/WorklogBar")
    ]
)
