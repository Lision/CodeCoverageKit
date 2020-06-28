// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "CodeCoverageKit",
    products: [
        .library(
            name: "CodeCoverageKit",
            targets: ["CodeCoverageKit", "InstrProfiling"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "InstrProfiling",
            dependencies: [],
            path: "Sources/InstrProfiling"
        ),
        .target(
            name: "CodeCoverageKit",
            dependencies: ["InstrProfiling"]
        ),
        .testTarget(
            name: "CodeCoverageKitTests",
            dependencies: ["CodeCoverageKit"]
        ),
    ]
)
