// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "kcal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "kcal", dependencies: ["KcalCore"]),
        .target(name: "KcalCore"),
        .testTarget(name: "kcalTests", dependencies: ["KcalCore"]),
    ],
    swiftLanguageModes: [.v5]
)
