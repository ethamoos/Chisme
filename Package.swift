// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Chisme",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Chisme",
            targets: ["Chisme"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Chisme",
            dependencies: [],
            path: ".",
            sources: [
                "ChismeApp.swift",
                "ContentView.swift",
                "FileManager+Extensions.swift",
                "AppState.swift",
                "HelpView.swift"
            ],
            resources: [
                .copy("EXAMPLE.md")
            ]
        )
    ]
)
