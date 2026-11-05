// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KeyHop",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "KeyHop"),
        .testTarget(name: "KeyHopTests", dependencies: ["KeyHop"])
    ]
)
