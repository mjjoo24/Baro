// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Baro",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "BaroCore",
            path: "Sources/BaroCore"
        ),
        .executableTarget(
            name: "Baro",
            dependencies: ["BaroCore"],
            path: "Sources/Baro",
            exclude: ["Resources/Info.plist", "Resources/AppIcon.icns"]
        ),
        .testTarget(
            name: "BaroCoreTests",
            dependencies: ["BaroCore"],
            path: "Tests/BaroCoreTests"
        )
    ]
)
