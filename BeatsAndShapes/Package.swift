// swift-tools-version:5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "BeatsAndShapes",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .executable(name: "BeatsAndShapes", targets: ["BeatsAndShapes"]),
        .executable(name: "MusicGenerator", targets: ["MusicGenerator"])
    ],
    dependencies: [
        // Swift 5.9+ modern dependencies for 2025 standards
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.3"),
        .package(url: "https://github.com/realm/SwiftLint", from: "0.54.0"),
        .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.2")
    ],
    targets: [
        // Main app with 2025 Swift features
        .executableTarget(
            name: "BeatsAndShapes",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Numerics", package: "swift-numerics")
            ],
            path: "Sources/BeatsAndShapes",
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),
        
        // Music generator with enhanced features
        .executableTarget(
            name: "MusicGenerator",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/MusicGenerator"
         ),
        
        // Comprehensive test suite
        .testTarget(
            name: "BeatsAndShapesTests",
            dependencies: [
                "BeatsAndShapes",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "Tests/BeatsAndShapesTests",
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),
        
        // Performance benchmarks
        .executableTarget(
            name: "PerformanceBenchmarks",
            dependencies: [
                "BeatsAndShapes",
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Benchmarks/PerformanceBenchmarks"
        )
    ]
)
