// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DockPin",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DockPin", targets: ["DockPin"])
    ],
    targets: [
        .executableTarget(
            name: "DockPin",
            path: "Sources/DockPin"
        )
    ]
)
