// swift-tools-version: 6.2
import PackageDescription

// Reine Rechenlogik ohne UI und ohne Datenbank, damit sie schnell per `swift test` prüfbar ist.
let package = Package(
    name: "PensumCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PensumCore", targets: ["PensumCore"]),
    ],
    targets: [
        .target(name: "PensumCore"),
        .testTarget(name: "PensumCoreTests", dependencies: ["PensumCore"]),
    ]
)
