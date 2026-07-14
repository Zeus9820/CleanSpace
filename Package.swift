// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CleanSpace",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "CleanSpaceCore", targets: ["CleanSpaceCore"]),
        .executable(name: "CleanSpaceDirect", targets: ["CleanSpaceDirect"]),
        .executable(name: "CleanSpaceStore", targets: ["CleanSpaceStore"])
    ],
    targets: [
        .target(name: "CleanSpaceCore"),
        .executableTarget(name: "CleanSpaceDirect", dependencies: ["CleanSpaceCore"], resources: [.process("Resources")]),
        .executableTarget(name: "CleanSpaceStore", dependencies: ["CleanSpaceCore"], resources: [.process("Resources")]),
        .testTarget(name: "CleanSpaceCoreTests", dependencies: ["CleanSpaceCore"])
    ]
)
