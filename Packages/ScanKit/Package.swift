// swift-tools-version: 6.0
import PackageDescription

// Pure-Swift scan engine: payload parsing, safe-link check, CSV, QR payloads.
// No UI or Apple frameworks beyond Foundation, so it can move into SliceLibrary later.
let package = Package(
    name: "ScanKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ScanKit", targets: ["ScanKit"])
    ],
    targets: [
        .target(name: "ScanKit"),
        .testTarget(name: "ScanKitTests", dependencies: ["ScanKit"]),
    ]
)
