// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BeatsAndShapes",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .executable(name: "BeatsAndShapes", targets: ["BeatsAndShapes"]),
        .executable(name: "MusicGenerator", targets: ["MusicGenerator"])
    ],
    targets: [
        .executableTarget(
            name: "BeatsAndShapes",
            dependencies: [],
            path: "Sources/BeatsAndShapes"
        ),
        .executableTarget(
            name: "MusicGenerator",
            dependencies: [],
            path: "Sources/MusicGenerator"
        ),
        .testTarget(
            name: "BeatsAndShapesTests",
            dependencies: ["BeatsAndShapes"],
            path: "Tests/BeatsAndShapesTests"
        )
    ]
)
