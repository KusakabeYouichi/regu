// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReguKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "ReguCore", targets: ["ReguCore"]),
        .library(name: "ReguUI", targets: ["ReguUI"])
    ],
    targets: [
        .target(name: "ReguCore"),
        .target(name: "ReguUI", dependencies: ["ReguCore"], resources: [.process("Resources")]),
        .testTarget(name: "ReguCoreTests", dependencies: ["ReguCore"])
    ]
)
