// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MiniNotch",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "MiniNotch", targets: ["MiniNotch"])],
    targets: [
        .executableTarget(name: "MiniNotch", path: "src"),
        .testTarget(name: "MiniNotchTests", dependencies: ["MiniNotch"], path: "test"),
    ],
    swiftLanguageModes: [.v5]
)
