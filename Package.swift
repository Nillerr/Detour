// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Detour",
    platforms: [
        .macOS(.v11), .iOS(.v14)
    ],
    products: [
        .library(
            name: "Detour",
            targets: ["Detour"]),
    ],
    targets: [
        .target(
            name: "Detour",
            dependencies: []),
        .testTarget(
            name: "DetourTests",
            dependencies: ["Detour"]),
    ]
)
