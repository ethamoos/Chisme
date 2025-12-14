// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Chisme",
    platforms: [
        .macOS(.v13) // macOS Ventura
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
                "FileManager+Extensions.swift"
            ]
        )
    ]
)
