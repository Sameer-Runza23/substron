// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "SubstronApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SubstronApp"
        ),
        .testTarget(
            name: "SubstronAppTests",
            dependencies: ["SubstronApp"]
        ),
    ]
)
