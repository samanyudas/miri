// swift-tools-version: 6.2
import PackageDescription

let isolation: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Miri",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "Miri", targets: ["Miri"]),
        .executable(name: "AXFixture", targets: ["AXFixture"]),
    ],
    targets: [
        .target(name: "MiriCore"),
        .executableTarget(name: "Miri", dependencies: ["MiriCore"], swiftSettings: isolation),
        .executableTarget(name: "AXFixture", swiftSettings: isolation),
        .testTarget(name: "MiriCoreTests", dependencies: ["MiriCore"]),
    ]
)
