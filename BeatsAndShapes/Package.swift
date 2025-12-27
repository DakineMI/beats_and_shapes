// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BeatsAndShapes",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.executable(name: "BeatsAndShapes", targets: ["BeatsAndShapes"])],
    targets: [.executableTarget(name: "BeatsAndShapes", path: "Sources/BeatsAndShapes")]
)
