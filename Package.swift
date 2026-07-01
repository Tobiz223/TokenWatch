// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenWatch",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "TokenWatchCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "TokenWatch",
            dependencies: ["TokenWatchCore"]
        ),
        .testTarget(
            name: "TokenWatchCoreTests",
            dependencies: ["TokenWatchCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
