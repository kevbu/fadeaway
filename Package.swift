// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FadeAway",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "FadeAwayCore"),
        .executableTarget(name: "FadeAway", dependencies: ["FadeAwayCore"]),
        .testTarget(name: "FadeAwayCoreTests", dependencies: ["FadeAwayCore"]),
    ]
)
