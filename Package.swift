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
        .target(
            name: "ProgramizerKit",
            dependencies: [],
            path: "Sources/Programizer",
            exclude: [
                "ProgramizerAPI.swift"
            ]
        ),
        .target(
            name: "DMGeniusKit",
            dependencies: [],
            path: "Sources/DMGenius",
            exclude: [
                "DMGeniusAPI.swift"
            ]
        ),
        .executableTarget(
            name: "Chisme",
            dependencies: [
                .target(name: "ProgramizerKit"),
                .target(name: "DMGeniusKit")
            ],
            path: ".",
            sources: [
                "ChismeApp.swift",
                "ContentView.swift",
                "FileManager+Extensions.swift",
                "AppState.swift",
                "HelpView.swift",
                "ProgramizerView.swift",
                "DMGeniusView.swift"
            ],
            resources: [
                .copy("EXAMPLE.md")
            ]
        )
    ]
)
