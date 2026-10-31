// swift-tools-version: 6.2
import PackageDescription

// A warning fails the build here and in CI, so warnings never pile up unread.
let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]
let isolation: [SwiftSetting] = strict + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Miri",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "Miri", targets: ["Miri"]),
        .executable(name: "AXFixture", targets: ["AXFixture"]),
    ],
    targets: [
        .target(name: "MiriCore", swiftSettings: strict),
        .executableTarget(name: "Miri", dependencies: ["MiriCore"], swiftSettings: isolation),
        .executableTarget(name: "AXFixture", swiftSettings: isolation),
        .testTarget(name: "MiriCoreTests", dependencies: ["MiriCore"], swiftSettings: strict),
    ]
)
