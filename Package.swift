// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TapThock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TapThock", targets: ["TapThock"]),
    ],
    targets: [
        .executableTarget(
            name: "TapThock",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ]
)
