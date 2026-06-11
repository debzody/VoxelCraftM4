// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoxelCraftM4",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "VoxelCraftM4",
            path: "Sources/VoxelCraftM4",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-O"], .when(configuration: .release))
            ]
        ),
    ]
)