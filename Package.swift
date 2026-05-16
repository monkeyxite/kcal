// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "kcal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "kcal"),
    ],
    swiftLanguageModes: [.v5]
)
