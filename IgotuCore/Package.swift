// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IgotuCore",
    platforms: [
        .iOS("26.5"),
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "IgotuCore",
            targets: ["IgotuCore"]
        )
    ],
    targets: [
        .target(name: "IgotuCore")
    ],
    swiftLanguageModes: [.v5]
)
