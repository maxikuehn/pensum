// swift-tools-version: 6.2
import PackageDescription

// Reine Rechenlogik ohne UI und ohne Datenbank, damit sie schnell per `swift test` prüfbar ist.
let package = Package(
    name: "ShiftCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ShiftCore", targets: ["ShiftCore"]),
    ],
    targets: [
        .target(name: "ShiftCore"),
        .testTarget(name: "ShiftCoreTests", dependencies: ["ShiftCore"]),
    ]
)
