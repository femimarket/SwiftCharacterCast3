// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "CharacterCast3",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "CharacterCast3",
            targets: ["CharacterCast3"]
        ),
    ],
    targets: [
        .target(
            name: "CharacterCast3",
            path: "CharacterCast3",
            exclude: [
                "CharacterCast3App.swift",
                "Assets.xcassets",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
