// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WordCadence",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WordCadence", targets: ["WordCadence"])],
    targets: [
        .target(name: "CadenceCore"),
        .executableTarget(name: "WordCadence", dependencies: ["CadenceCore"]),
        .testTarget(name: "CadenceCoreTests", dependencies: ["CadenceCore"])
    ]
)
