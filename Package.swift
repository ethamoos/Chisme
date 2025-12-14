// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Chisme",
    platforms: [
        .macOS(.v13)  // macOS Ventura and later
    ],
    products: [
        .executable(name: "Chisme", targets: ["ChismeApp"])
    ],
    targets: [
        // Library target containing the app logic
        .target(
            name: "Chisme"
        ),
        // Executable target that launches the app
        .executableTarget(
            name: "ChismeApp",
            dependencies: ["Chisme"]
        ),
        // Test target
        .testTarget(
            name: "ChismeTests",
            dependencies: ["Chisme"]
        ),
    ]
)
