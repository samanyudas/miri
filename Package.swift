// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MiriPermissionPrototype",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "MiriPrototype", targets: ["MiriPrototype"]),
        .executable(name: "AXFixture", targets: ["AXFixture"]),
    ],
    targets: [
        .executableTarget(name: "MiriPrototype", swiftSettings: [.defaultIsolation(MainActor.self)]),
        .executableTarget(name: "AXFixture", swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
