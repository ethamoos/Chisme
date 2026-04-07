Chisme
======

Chisme is a small macOS SwiftUI utility for quickly viewing and annotating plain-text snippets and notes. It provides a lightweight GUI with a Help menu that displays an example markdown document (EXAMPLE.md) so you can see how content will appear in the app.

What it does
-----------
- Presents a simple SwiftUI interface for working with short pieces of text.
- Includes a Help window that renders the repository's `EXAMPLE.md` as Markdown (or raw text if Markdown rendering is unavailable).
- Uses a small set of local files and fallbacks so the app works both when run from Xcode and when built as a product.

Quick start
-----------
Requirements
- macOS 11.0+ (or the platform targeted by the project settings)
- Xcode 12+ or Swift toolchain that supports SwiftUI

Open in Xcode
1. Open `Chisme.xcodeproj` or the workspace in Xcode.
2. (Optional) Add `EXAMPLE.md` to the app target’s Copy Bundle Resources if you want it to be bundled in release builds.
3. Build and Run (Cmd+R).

Run via Swift Package Manager (command line)
- From the project root:

```bash
swift build
swift run
```

Note: Running with SwiftPM will run the executable target in the current working directory; Help view uses an upward search & repository absolute-path fallback to locate `EXAMPLE.md` when it’s not bundled.

Using the app
-----------
- Open the app and use the UI to create or view short notes.
- Select the app menu Help → Show Help (or the configured keyboard shortcut) to open the Help sheet — the app will attempt to find and render `EXAMPLE.md` from the bundle or from common fallback locations.

Where `EXAMPLE.md` comes from
---------------------------
- The repository includes an `EXAMPLE.md` at the project root. When running from Xcode or SwiftPM, the running bundle is usually nested in DerivedData, so the app attempts several fallbacks to find the file:
  - Bundle resource (if `EXAMPLE.md` is added to Copy Bundle Resources or declared as a package resource).
  - Walk upward from the executable/bundle/CWD searching parent directories.
  - Final fallback checks the repository absolute path (useful when running locally from the repo).

If you want `EXAMPLE.md` to always be found in distributed/bundled builds
- Add it to the app target resources in Xcode (Target → Build Phases → Copy Bundle Resources).
- Or, if you use SwiftPM to build the release binary, add it to the executable target resources in `Package.swift`:

```swift
.executableTarget(
    name: "Chisme",
    dependencies: [],
    path: ".",
    sources: [
        "ChismeApp.swift",
        "ContentView.swift",
        "FileManager+Extensions.swift"
    ],
    resources: [
        .copy("EXAMPLE.md")
    ]
)
```

Troubleshooting
---------------
- "EXAMPLE.md not found in bundle or expected fallback locations." — If you see this message in the Help view, the app attempted to find the file in several places but failed. Two quick fixes:
  1. Add `EXAMPLE.md` to your app target's Copy Bundle Resources.
  2. Run the app from the repository root (or add the repository path as a fallback in code). The Help view currently already includes an absolute-repo-path fallback for the development workspace.

- If you want me to automatically add `EXAMPLE.md` as a package resource or update the Xcode project to include it, tell me which option you prefer and I can make that change.

Development notes
-----------------
- The project uses SwiftUI. Key source files you may want to look at:
  - `ChismeApp.swift` — app entry and menu commands
  - `ContentView.swift` — main UI and help-sheet presentation
  - `HelpView.swift` — loads and renders `EXAMPLE.md` (Markdown rendering with raw-text fallback)
  - `FileManager+Extensions.swift` — file utilities used by the app

License & Contribution
----------------------
This repository currently does not include a license file. If you plan to share or open-source this project, consider adding a LICENSE (for example MIT, Apache-2.0, etc.).

Questions / Next steps
---------------------
- I can add `EXAMPLE.md` as a packaged resource so Bundle lookup always succeeds (recommended for distribution).
- I can update the Xcode project file to include `EXAMPLE.md` in Copy Bundle Resources.
- I can remove or consolidate duplicate source files if you prefer a cleaner layout.

If you'd like any of the above, tell me which option and I’ll implement it.
