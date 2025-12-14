# Building and Running Chisme

## Prerequisites

This is a **macOS-only** application that requires:
- macOS Ventura (13.0) or later
- Xcode 14 or later with Swift 6.2+ support
- Command Line Tools installed

## Building from Source

### Option 1: Using Xcode

1. Open Terminal and navigate to the project directory
2. Open the Package.swift file in Xcode:
   ```bash
   open Package.swift
   ```
3. Wait for Xcode to resolve dependencies
4. Select the "Chisme" scheme from the scheme selector
5. Click the Run button (⌘R) or Build button (⌘B)

### Option 2: Using Swift Package Manager (Command Line)

1. Open Terminal and navigate to the project directory
2. Build the project:
   ```bash
   swift build -c release
   ```
3. Run the application:
   ```bash
   swift run
   ```

## Running Tests

To run the unit tests:

```bash
swift test
```

## Creating a Standalone Application

To create a standalone `.app` bundle:

1. Build the release version:
   ```bash
   swift build -c release
   ```

2. The executable will be in:
   ```
   .build/release/Chisme
   ```

3. You can run it directly:
   ```bash
   ./.build/release/Chisme
   ```

## Troubleshooting

### "SwiftUI module not found"

This error occurs when trying to build on a non-macOS platform. SwiftUI for macOS is only available on macOS systems.

### Permission Issues

If the app cannot access folders, you may need to grant permissions:
1. Open System Settings > Privacy & Security > Files and Folders
2. Grant Chisme permission to access the necessary folders

## Distribution

To distribute the app:

1. Build with release configuration
2. Archive the app using Xcode (Product > Archive)
3. Export the app for distribution
4. Notarize the app (for distribution outside the App Store)

For detailed instructions on app distribution, see [Apple's Distribution Guide](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).
