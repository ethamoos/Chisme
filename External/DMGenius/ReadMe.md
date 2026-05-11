# DMGenius

DMGenius is a small macOS utility written in Swift/SwiftUI for creating macOS .dmg (disk image) files. It provides a simple UI to package an application or folder into a DMG, handling common options and packaging steps via the `DMGCreator` component.

## Features

- Graphical macOS app built with SwiftUI.
- Uses `DMGCreator.swift` to create DMG files programmatically.
- Includes unit and UI tests to verify behavior (`DMGeniusTests`, `DMGeniusUITests`).

## Requirements

- macOS (developed and tested on recent macOS versions)
- Xcode 14+ (recommended)
- Swift toolchain compatible with the project settings

## Getting started

1. Open the Xcode workspace or project:

   - `DMGenius.xcodeproj` (or open `DMGenius.xcworkspace` if you use workspace features)

2. Build and run the app on your Mac using Xcode.

3. Use the UI to select the app or folder you want to package and follow the on-screen steps to create a DMG file.

## Running tests

- Open the project in Xcode and run the Test action (Product → Test).
- Or run tests from the command line with xcodebuild, for example:

  xcodebuild -project DMGenius.xcodeproj -scheme DMGenius -sdk macosx -configuration Debug test

(You may need to adjust scheme or workspace flags depending on your Xcode setup.)

## Project layout

- `DMGenius/` — main app sources (SwiftUI views, app entry, `DMGCreator.swift`).
- `DMGeniusTests/` — unit tests.
- `DMGeniusUITests/` — UI tests.

## Contributing

Feel free to open issues or submit pull requests. Small, focused changes with tests are easiest to review.

## License

Include your preferred license here (for example, MIT). If you don't have a license yet, consider adding one to clarify the project's terms.

---

If you'd like, I can:
- Rename the file to `README.md` (common convention).
- Add screenshots or a short demo GIF.
- Expand usage instructions with specific options exposed by `DMGCreator.swift` if you want more detail.

Tell me which of these you'd like next.