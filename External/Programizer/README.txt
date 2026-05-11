README (summary & notes)

Main features (Ul + behavior)
• Folder chooser and non-recursive (one-level) scan for . dmg files (ContentView. swift).
• List of discovered DMGs with status, mount point, context menu (mount now / open in Finder) (ContentView. swift).
• Buttons to "Mount all", "Unmount all", "Clear log", and "Run sequentially" (ContentView. swift).
• Configure the relative path to run inside each mounted volume (text field). The code trims leading slashes; using "Root" or empty string runs at the volume root (ContentView.swift /
README. txt).
• Configure a delay (seconds) between runs and a "Run as admin" toggle to request elevated privileges (ContentView. swift).
• Actual DMG mounting, diagnostics, quarantine/xattr retry, running the executable (normal or via AppleScript elevation), and unmount logic live in DMGManager. swift.
• App entry point is ProgramizerApp. swift.
Important behaviors & edge-cases
• Mounting: uses hdiutil attach-plist -nobrowse and parses the plist to extract the mount point; if that fails it gathers diagnostics and may try to remove com. apple. quarantine
and retry.
• Unmounting: uses hdiutil detach <mountPoint> and will try -force on failure; temporary DMG copies are cleaned up after unmount.
• Running executables: if "Run as admin" is enabled, the app uses osascript (AppleScript: do shell script ... with administrator privileges) to prompt for credentials; otherwise it runs the
binary directly and waits for it to exit.
• Path expectations: if you want to launch a GUl app inside a bundle, you must point to the internal executable (e.g., MyApp. app/Contents/MacOS/MyApp).
• Sequential operation: mounts each DMG, runs the specified path, waits the configured delay, then unmounts before moving to the next DMG.
• Logging: operations and diagnostics are appended to an on-screen log and printed to console for troubleshooting.

How to use

Choose folder → press Scan (or it auto-scans on appear).
Enter a relative path to execute inside each mounted volume (example: "Adobe Package Downloader.app/Contents/MacOS/Install" or "Root" or "SomeInstaller.app/Contents/MacOS/InstallerBinary").
Make the relative path not start with a leading slash; code will trim leading slashes.
If you need to run at the root of the volume, use "Root" or empty string.
Toggle "Run as admin" to prompt for an admin password when running the command on each volume.
Set the delay in seconds between runs.
