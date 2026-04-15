// ...existing code...
// Replaced with original Programizer DMGManager implementation (trimmed for brevity in patch view)
// Full content from Programizer/Programizer/DMGManager.swift was copied here to provide complete functionality.
import Foundation
import Combine
import AppKit

public final class DMGItem: Identifiable, ObservableObject {
    public let id = UUID()
    public let url: URL
    public let name: String
    @Published public var mountPoint: String?
    @Published public var statusText: String = "Idle"

    public var isMounted: Bool { mountPoint != nil }

    public init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
    }
}

@MainActor
public final class DMGManager: ObservableObject {
    @Published public var folderPath: URL?
    @Published public private(set) var items: [DMGItem] = []
    @Published public var log: [String] = []
    // User-editable script to run on mounted DMGs
    @Published public var customScript: String = ""
    private var cancellables = Set<AnyCancellable>()

    // Temporary copies tracking
    private var tempCopies: [String: URL] = [:]

    // Date formatter used for log timestamps
    private let logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale.current
        f.timeZone = TimeZone.current
        return f
    }()

    public init() {}

    // Bring the app forward and notify the user an authentication dialog will appear.
    private func notifyAuthenticationWillBeRequested(message: String = "The system will prompt for administrator credentials.") {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Authentication required"
            alert.informativeText = message + "\nPlease look for the system dialog and enter administrator credentials when prompted."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // Run an AppleScript 'do shell script "..." with administrator privileges', retrying up to `attempts` times
    // Returns a tuple (status, stdout, stderr) where status is the process exit code from osascript
    private func runAppleScriptAdmin(shellCommand: String, attempts: Int = 3, delayBetweenAttemptsSeconds: UInt64 = 1) async -> (Int32, String, String) {
         // Build AppleScript command
         // Escape double quotes for embedding in AppleScript string
         let escaped = shellCommand.replacingOccurrences(of: "\"", with: "\\\"")
         // Build a safe appleScript string by embedding the escaped shell command
         let apple = "do shell script \"\(escaped)\" with administrator privileges"

         for attempt in 1...attempts {
             // Bring app forward and notify so user can spot the system dialog
             notifyAuthenticationWillBeRequested(message: "The app will request administrator credentials to run: \(shellCommand)")

             let task = Process()
             task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
             task.arguments = ["-e", apple]
             let outPipe = Pipe()
             let errPipe = Pipe()
             task.standardOutput = outPipe
             task.standardError = errPipe
             do {
                 try task.run()
             } catch {
                 return (-1, "", "failed-to-start-osascript: \(error.localizedDescription)")
             }
             task.waitUntilExit()
             let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
             let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

             if !out.isEmpty { DispatchQueue.main.async { self.appendLog("elev stdout: \(out.trimmingCharacters(in: .whitespacesAndNewlines))") } }
             if !err.isEmpty { DispatchQueue.main.async { self.appendLog("elev stderr: \(err.trimmingCharacters(in: .whitespacesAndNewlines))") } }

             if task.terminationStatus == 0 {
                 return (task.terminationStatus, out, err)
             }

             // If auth failed, log and retry after a short pause (user may have entered wrong password).
             DispatchQueue.main.async { self.appendLog("AppleScript admin attempt \(attempt) failed (status=\(task.terminationStatus)).") }
             if attempt < attempts {
                 // Sleep briefly before retrying
                 let nanos = delayBetweenAttemptsSeconds * 1_000_000_000
                 try? await Task.sleep(nanoseconds: nanos)
             }
         }

         // Final attempt failed; return last-known non-zero status. We did not capture the last status here explicitly, but the caller will have logs.
         return (-1, "", "appleScript attempts exhausted")
     }

    public func appendLog(_ s: String) {
        let ts = logDateFormatter.string(from: Date())
        let line = "[\(ts)] \(s)"
        log.append(line)
        print(line)
    }

    public func clearLog() {
        log.removeAll()
    }

    // Run a user-provided shell script on every DMG currently mounted by this manager.
    // - script: optional script text; if nil, uses `customScript`.
    // - delaySeconds: delay between runs on different DMGs
    // - requireAdmin: if true, uses AppleScript (osascript) to request admin privileges
    // Run the user-provided script on each mounted DMG. Returns true if all runs completed with exit code 0.
    public func runScriptOnMounted(script: String? = nil, delaySeconds: Int, requireAdmin: Bool) async -> Bool {
        let scriptText = (script ?? customScript).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scriptText.isEmpty else {
            appendLog("No script provided; nothing to run.")
            return false
        }

        var overallSuccess = true

        // Write script to a temporary file
        let tmpDir = FileManager.default.temporaryDirectory
        let tmpFile = tmpDir.appendingPathComponent("programizer_script_\(UUID().uuidString).sh")
        do {
            try scriptText.data(using: .utf8)?.write(to: tmpFile, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpFile.path)
            appendLog("Wrote temporary script to \(tmpFile.path)")
        } catch {
            appendLog("Failed to write temporary script: \(error.localizedDescription)")
            return false
        }

        // Ensure cleanup
        defer {
            do {
                try FileManager.default.removeItem(at: tmpFile)
                appendLog("Removed temporary script: \(tmpFile.path)")
            } catch {
                appendLog("Warning: failed to remove temporary script: \(error.localizedDescription)")
            }
        }

        // Gather mounted items
        let mounted = items.filter { $0.isMounted }
        if mounted.isEmpty {
            appendLog("No mounted DMGs to run the script on.")
            return false
        }

        for item in mounted {
            guard let mp = item.mountPoint else { continue }
            appendLog("Running script on \(item.name) (mount: \(mp))")

            if requireAdmin {
                // Build inner shell command that sets MOUNTPOINT and calls the script with mountpoint as $1
                // Escape double quotes in paths
                let escScript = tmpFile.path.replacingOccurrences(of: "\"", with: "\\\"")
                let escMp = mp.replacingOccurrences(of: "\"", with: "\\\"")
                let escName = item.name.replacingOccurrences(of: "\"", with: "\\\"")
                let escFile = item.url.path.replacingOccurrences(of: "\"", with: "\\\"")
                // Pass positional args: $1 = mountpoint, $2 = dmg name, $3 = original dmg file path
                let inner = "MOUNTPOINT=\"\(escMp)\" DMG_NAME=\"\(escName)\" DMG_FILE=\"\(escFile)\" \"\(escScript)\" \"\(escMp)\" \"\(escName)\" \"\(escFile)\""
                // Escape inner for embedding in AppleScript's do shell script "..."
                let innerEscaped = inner.replacingOccurrences(of: "\"", with: "\\\"")
                let apple = "do shell script \"\(innerEscaped)\" with administrator privileges"

                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                task.arguments = ["-e", apple]
                let outPipe = Pipe()
                let errPipe = Pipe()
                task.standardOutput = outPipe
                task.standardError = errPipe
                do {
                    try task.run()
                    task.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if !out.isEmpty { appendLog("Script stdout for \(item.name): \(out.trimmingCharacters(in: .whitespacesAndNewlines))") }
                    if !err.isEmpty { appendLog("Script stderr for \(item.name): \(err.trimmingCharacters(in: .whitespacesAndNewlines))") }
                    if task.terminationStatus != 0 {
                        appendLog("Script (admin) exited with status \(task.terminationStatus) for \(item.name)")
                        overallSuccess = false
                    } else {
                        appendLog("Script (admin) completed for \(item.name)")
                    }
                } catch {
                    appendLog("Failed to run admin script for \(item.name): \(error.localizedDescription)")
                    overallSuccess = false
                }
            } else {
                // Run without admin; set environment variable MOUNTPOINT and pass mountpoint as first arg
                let task = Process()
                task.executableURL = URL(fileURLWithPath: tmpFile.path)
                // Pass positional args: mountpoint, dmg name, original dmg path
                task.arguments = [mp, item.name, item.url.path]
                var env = ProcessInfo.processInfo.environment
                env["MOUNTPOINT"] = mp
                env["DMG_NAME"] = item.name
                env["DMG_FILE"] = item.url.path
                task.environment = env
                let outPipe = Pipe()
                let errPipe = Pipe()
                task.standardOutput = outPipe
                task.standardError = errPipe
                do {
                    try task.run()
                    task.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if !out.isEmpty { appendLog("Script stdout for \(item.name): \(out.trimmingCharacters(in: .whitespacesAndNewlines))") }
                    if !err.isEmpty { appendLog("Script stderr for \(item.name): \(err.trimmingCharacters(in: .whitespacesAndNewlines))") }
                    if task.terminationStatus != 0 {
                        appendLog("Script exited with status \(task.terminationStatus) for \(item.name)")
                        overallSuccess = false
                    } else {
                        appendLog("Script completed for \(item.name)")
                    }
                } catch {
                    appendLog("Failed to run script for \(item.name): \(error.localizedDescription)")
                    overallSuccess = false
                }
            }

            if delaySeconds > 0 {
                appendLog("Waiting \(delaySeconds) seconds before next script run...")
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
            }
        }

        return overallSuccess
    }

    // Scan the chosen folder, one level deep, for .dmg files
    public func scanForDMGs() {
        items.removeAll()
        guard let folder = folderPath else {
            appendLog("No folder selected.")
            return
        }
        appendLog("Scanning \(folder.path) for .dmg (1 level)...")
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let dmgs = contents.filter { $0.pathExtension.lowercased() == "dmg" }
            items = dmgs.map { DMGItem(url: $0) }
            appendLog("Found \(items.count) .dmg files.")
        } catch {
            appendLog("Scan error: \(error.localizedDescription)")
        }
    }

    // Mount a single DMG, returning mountPoint (or nil)
    public func mount(item: DMGItem) async {
        item.statusText = "Mounting..."
        appendLog("Mounting \(item.name)...")
        do {
            if let mp = try await mountDMG(dmgURL: item.url) {
                item.mountPoint = mp
                item.statusText = "Mounted at \(mp)"
                appendLog("Mounted \(item.name) -> \(mp)")
            } else {
                item.statusText = "Mount failed"
                appendLog("Mount returned no mount point for \(item.name)")
            }
        } catch {
            item.statusText = "Mount error"
            appendLog("Mount error for \(item.name): \(error.localizedDescription)")
        }
    }

    // Mount all items sequentially
    public func mountAll() async {
        for item in items {
            if !item.isMounted {
                await mount(item: item)
            }
        }
    }

    // Unmount a single item
    public func unmount(item: DMGItem) async {
        guard let mp = item.mountPoint else {
            appendLog("Item not mounted: \(item.name)")
            return
        }
        item.statusText = "Unmounting..."
        appendLog("Unmounting \(item.name) at \(mp)...")
        do {
            try await unmountMountPoint(mp)
            item.mountPoint = nil
            item.statusText = "Unmounted"
            appendLog("Unmounted \(item.name)")
        } catch {
            item.statusText = "Unmount error"
            appendLog("Unmount error for \(item.name): \(error.localizedDescription)")
        }
    }

    // Unmount all
    public func unmountAll() async {
        for item in items {
            if item.isMounted {
                await unmount(item: item)
            }
        }
    }

    // Run sequentially: mount, run relative path, delay, unmount
    public func runSequential(relativePath: String, delaySeconds: Int, requireAdmin: Bool) async {
        appendLog("Starting sequential run: relativePath='\(relativePath)', delay=\(delaySeconds)s, admin=\(requireAdmin)")
        for item in items {
            appendLog("Processing \(item.name)")
            await mount(item: item)
            guard let mp = item.mountPoint else {
                appendLog("Skipping \(item.name) because mount failed.")
                continue
            }

            // Build the full path to run
            var fullPath = mp
            // Ensure relativePath doesn't have an absolute root
            let rel = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !rel.isEmpty {
                fullPath = (fullPath as NSString).appendingPathComponent(rel)
            }
            appendLog("Attempting to run: \(fullPath)")

            do {
                try await runExecutable(atPath: fullPath, requireAdmin: requireAdmin)
                appendLog("Run finished for \(item.name)")
            } catch {
                appendLog("Run error for \(item.name): \(error.localizedDescription)")
            }

            if delaySeconds > 0 {
                appendLog("Waiting \(delaySeconds) seconds...")
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
            }

            await unmount(item: item)
        }
        appendLog("Sequential run complete.")
    }

    // MARK: - Helpers for mounting/unmounting and running

    public enum DMGError: LocalizedError {
        case noOutput
        case unableToParse
        case mountFailed(String)
        case runFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noOutput:
                return "No output from hdiutil"
            case .unableToParse:
                return "Unable to parse hdiutil plist output"
            case .mountFailed(let msg):
                return "Mount failed: \(msg)"
            case .runFailed(let msg):
                return "Run failed: \(msg)"
            }
        }
    }

    // Use hdiutil attach -plist to get mount point(s)
    private func mountDMG(dmgURL: URL) async throws -> String? {
        // Ensure the DMG exists before attempting to mount
        guard FileManager.default.fileExists(atPath: dmgURL.path) else {
            throw DMGError.mountFailed("File not found: \(dmgURL.path)")
        }

        // Helper to run a command and capture stdout/stderr
        func runCapture(_ executable: String, _ args: [String]) -> (out: String, err: String, status: Int32) {
            let t = Process()
            t.executableURL = URL(fileURLWithPath: executable)
            t.arguments = args
            let o = Pipe()
            let e = Pipe()
            t.standardOutput = o
            t.standardError = e
            do {
                try t.run()
            } catch {
                return ("", "failed-to-run: \(error.localizedDescription)", -1)
            }
            t.waitUntilExit()
            let od = o.fileHandleForReading.readDataToEndOfFile()
            let ed = e.fileHandleForReading.readDataToEndOfFile()
            return (String(data: od, encoding: .utf8) ?? "", String(data: ed, encoding: .utf8) ?? "", t.terminationStatus)
        }

        // Primary attempt (plist output)
        var primary = runCapture("/usr/bin/hdiutil", ["attach", "-plist", "-nobrowse", dmgURL.path])
        let stdoutData = primary.out.data(using: .utf8) ?? Data()

        // If process returns non-zero, surface stderr
        if primary.status != 0 {
            // If stderr hints at quarantine or permission issues, try a diagnostic + xattr retry below
            // but first attempt to return the stderr for immediate feedback
            // fall through to diagnostic handling
        }

        // If we have stdout data that looks like a plist, try to parse it
        if !stdoutData.isEmpty {
            do {
                let plistAny = try PropertyListSerialization.propertyList(from: stdoutData, options: [], format: nil)
                if let dict = plistAny as? [String: Any],
                   let entities = dict["system-entities"] as? [[String: Any]] {
                     for ent in entities {
                         if let mp = ent["mount-point"] as? String {
                             return mp
                         }
                     }
                     // parsed but no mount point
                     return nil
                }
            } catch {
                // parsing failed, continue to diagnostics
            }
        }

        // If we reach here, hdiutil gave no useful plist output. Run diagnostics and attempt a quarantine removal retry when appropriate.
        var diagParts: [String] = []
        diagParts.append("Initial hdiutil (plist) stdout len=\(primary.out.count), stderr=\(primary.err.trimmingCharacters(in: .whitespacesAndNewlines)), exit=\(primary.status)")

        // File attributes
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: dmgURL.path)
            if let size = attrs[.size] as? NSNumber {
                diagParts.append("size=\(size.int64Value)")
            }
            if let perm = attrs[.posixPermissions] as? NSNumber {
                diagParts.append(String(format: "posix=0%o", perm.intValue))
            }
            if let mod = attrs[.modificationDate] as? Date {
                diagParts.append("modDate=\(mod)")
            }
        } catch {
            diagParts.append("attributes-error: \(error.localizedDescription)")
        }

        // Run `file` on the dmg
        let fileRes = runCapture("/usr/bin/file", [dmgURL.path])
        if !fileRes.out.isEmpty { diagParts.append("file-out: \(fileRes.out.trimmingCharacters(in: .whitespacesAndNewlines))") }
        if !fileRes.err.isEmpty { diagParts.append("file-err: \(fileRes.err.trimmingCharacters(in: .whitespacesAndNewlines))") }

        // Run hdiutil attach without -plist to see textual messages
        let hdiRes = runCapture("/usr/bin/hdiutil", ["attach", "-nobrowse", "-noverify", dmgURL.path])
        if !hdiRes.out.isEmpty { diagParts.append("hdiutil-out: \(hdiRes.out.trimmingCharacters(in: .whitespacesAndNewlines))") }
        if !hdiRes.err.isEmpty { diagParts.append("hdiutil-err: \(hdiRes.err.trimmingCharacters(in: .whitespacesAndNewlines))") }
        diagParts.append("hdiutil-exit-status: \(hdiRes.status)")

        let diag = diagParts.joined(separator: "\n")
        DispatchQueue.main.async { self.appendLog("Mount diagnostics for \(dmgURL.lastPathComponent):\n\(diag)") }

        // If hdiutil output hints at quarantine or Gatekeeper, attempt to remove quarantine attribute and retry once
        let combined = (primary.err + " " + hdiRes.err + " " + hdiRes.out).lowercased()
        let shouldTryXattr = combined.contains("quarantine") || combined.contains("operation not permitted") || combined.contains("not permitted") || combined.contains("permission denied") || hdiRes.status != 0

        if shouldTryXattr {
            DispatchQueue.main.async { self.appendLog("Attempting to remove com.apple.quarantine xattr and retry for \(dmgURL.lastPathComponent)") }
            let xattrRes = runCapture("/usr/bin/xattr", ["-d", "com.apple.quarantine", dmgURL.path])
            if xattrRes.status == 0 {
                DispatchQueue.main.async { self.appendLog("Removed quarantine attribute, retrying hdiutil...") }
                let retryRes = runCapture("/usr/bin/hdiutil", ["attach", "-plist", "-nobrowse", "-noverify", dmgURL.path])
                let retryStdout = retryRes.out.data(using: .utf8) ?? Data()
                let retryStderr = retryRes.err
                if retryRes.status == 0 && !retryStdout.isEmpty {
                    // Try parse retry stdout
                    do {
                        let plistAny = try PropertyListSerialization.propertyList(from: retryStdout, options: [], format: nil)
                        if let dict = plistAny as? [String: Any],
                           let entities = dict["system-entities"] as? [[String: Any]] {
                            for ent in entities {
                                if let mp = ent["mount-point"] as? String {
                                    DispatchQueue.main.async { self.appendLog("Mount retry succeeded: \(mp)") }
                                    return mp
                                }
                            }
                            DispatchQueue.main.async { self.appendLog("Mount retry parsed but no mount point found") }
                            throw DMGError.unableToParse
                        }
                    } catch {
                        DispatchQueue.main.async { self.appendLog("Mount retry plist parse error: \(error.localizedDescription)") }
                        throw DMGError.unableToParse
                    }
                } else {
                    DispatchQueue.main.async { self.appendLog("Mount retry failed: stderr=\(retryStderr), exit=\(retryRes.status)") }
                    throw DMGError.mountFailed("Retry failed: \(retryRes.err.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            } else {
                DispatchQueue.main.async { self.appendLog("Failed to remove quarantine attribute: \(xattrRes.err.trimmingCharacters(in: .whitespacesAndNewlines))") }
                // Try an elevated xattr removal via AppleScript (prompts for admin credentials)
                DispatchQueue.main.async { self.appendLog("Attempting elevated xattr removal via admin prompt for \(dmgURL.lastPathComponent)...") }
                // Notify the user and bring the app forward so the system auth dialog isn't missed.
                notifyAuthenticationWillBeRequested(message: "The app will request permission to remove a quarantine attribute from the disk image '")
                let escapedPath = dmgURL.path.replacingOccurrences(of: "\"", with: "\\\"")
                let appleCmd = "do shell script \"/usr/bin/xattr -d com.apple.quarantine \\\"\(escapedPath)\\\"\" with administrator privileges"
                let elevTask = Process()
                elevTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                elevTask.arguments = ["-e", appleCmd]
                let elevOut = Pipe()
                let elevErr = Pipe()
                elevTask.standardOutput = elevOut
                elevTask.standardError = elevErr
                var elevSucceeded = false
                do {
                    try elevTask.run()
                    elevTask.waitUntilExit()
                    elevSucceeded = elevTask.terminationStatus == 0
                    let o = String(data: elevOut.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let e = String(data: elevErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if !o.isEmpty { DispatchQueue.main.async { self.appendLog("elev xattr stdout: \(o.trimmingCharacters(in: .whitespacesAndNewlines))") } }
                    if !e.isEmpty { DispatchQueue.main.async { self.appendLog("elev xattr stderr: \(e.trimmingCharacters(in: .whitespacesAndNewlines))") } }
                } catch {
                    DispatchQueue.main.async { self.appendLog("Elevated xattr removal failed to start: \(error.localizedDescription)") }
                    elevSucceeded = false
                }

                if elevSucceeded {
                    DispatchQueue.main.async { self.appendLog("Elevated xattr removal succeeded; retrying hdiutil attach...") }
                    let retryRes = runCapture("/usr/bin/hdiutil", ["attach", "-plist", "-nobrowse", "-noverify", dmgURL.path])
                    let retryStdout = retryRes.out.data(using: .utf8) ?? Data()
                    let retryStderr = retryRes.err
                    if retryRes.status == 0 && !retryStdout.isEmpty {
                        do {
                            let plistAny = try PropertyListSerialization.propertyList(from: retryStdout, options: [], format: nil)
                            if let dict = plistAny as? [String: Any],
                               let entities = dict["system-entities"] as? [[String: Any]] {
                                for ent in entities {
                                    if let mp = ent["mount-point"] as? String {
                                        DispatchQueue.main.async { self.appendLog("Mount retry succeeded after elevated xattr: \(mp)") }
                                        return mp
                                    }
                                }
                                DispatchQueue.main.async { self.appendLog("Mount retry parsed but no mount point found") }
                                throw DMGError.unableToParse
                            }
                        } catch {
                            DispatchQueue.main.async { self.appendLog("Mount retry plist parse error: \(error.localizedDescription)") }
                            throw DMGError.unableToParse
                        }
                    } else {
                        DispatchQueue.main.async { self.appendLog("Mount retry failed after elevated xattr: stderr=\(retryStderr), exit=\(retryRes.status)") }
                        // Fall through to copy fallback below
                    }
                }

                 // If we cannot remove the xattr (e.g. Operation not permitted), try copying the DMG to a temporary location and attach from there.
                 DispatchQueue.main.async { self.appendLog("Attempting to copy DMG to temporary location and retry attach...") }
                 let tmpDir = FileManager.default.temporaryDirectory
                 let tmpURL = tmpDir.appendingPathComponent("programizer_copy_\(UUID().uuidString).dmg")
                 do {
                     try FileManager.default.copyItem(at: dmgURL, to: tmpURL)
                     DispatchQueue.main.async { self.appendLog("Copied to temp: \(tmpURL.path). Trying attach...") }
                     let copyRetry = runCapture("/usr/bin/hdiutil", ["attach", "-plist", "-nobrowse", "-noverify", tmpURL.path])
                     let copyStdout = copyRetry.out.data(using: .utf8) ?? Data()
                     if copyRetry.status == 0 && !copyStdout.isEmpty {
                         do {
                             let plistAny = try PropertyListSerialization.propertyList(from: copyStdout, options: [], format: nil)
                             if let dict = plistAny as? [String: Any],
                                let entities = dict["system-entities"] as? [[String: Any]] {
                                 for ent in entities {
                                     if let mp = ent["mount-point"] as? String {
                                         // Track the temporary copy for cleanup when unmounting
                                         self.tempCopies[mp] = tmpURL
                                         DispatchQueue.main.async { self.appendLog("Mount succeeded from temp copy: \(mp)") }
                                         return mp
                                     }
                                 }
                                 DispatchQueue.main.async { self.appendLog("Copy-mount parsed but no mount point found") }
                                 throw DMGError.unableToParse
                             }
                         } catch {
                             DispatchQueue.main.async { self.appendLog("Copy-mount plist parse error: \(error.localizedDescription)") }
                             throw DMGError.unableToParse
                         }
                     } else {
                         DispatchQueue.main.async { self.appendLog("Copy attach failed: stderr=\(copyRetry.err.trimmingCharacters(in: .whitespacesAndNewlines)), exit=\(copyRetry.status)") }
                         // Remove the temp copy if attach failed
                         try? FileManager.default.removeItem(at: tmpURL)
                         throw DMGError.mountFailed("Copy attach failed: \(copyRetry.err.trimmingCharacters(in: .whitespacesAndNewlines))")
                     }
                 } catch {
                     DispatchQueue.main.async { self.appendLog("Failed to copy DMG to temp or attach: \(error.localizedDescription)") }
                     throw DMGError.mountFailed("Failed to remove quarantine attribute: \(xattrRes.err.trimmingCharacters(in: .whitespacesAndNewlines))")
                 }
             }
         }

        // If we get here, we couldn't mount and didn't perform a successful retry; return the captured diagnostics as mount failure
        throw DMGError.mountFailed(diag)
    }

    private func unmountMountPoint(_ mountPoint: String) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        // Try detach with the mount point; hdiutil accepts mount points too
        task.arguments = ["detach", mountPoint]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            // Try force
            let task2 = Process()
            task2.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            task2.arguments = ["detach", "-force", mountPoint]
            task2.standardOutput = Pipe()
            task2.standardError = Pipe()
            try task2.run()
            task2.waitUntilExit()
            if task2.terminationStatus != 0 {
                throw DMGError.runFailed("hdiutil detach failed for \(mountPoint)")
            }
        }

        // Clean up any temporary copy used for this mount
        if let tmpURL = tempCopies[mountPoint] {
            do {
                try FileManager.default.removeItem(at: tmpURL)
                DispatchQueue.main.async { self.appendLog("Removed temporary DMG copy: \(tmpURL.path)") }
            } catch {
                DispatchQueue.main.async { self.appendLog("Warning: failed to remove temporary DMG copy: \(error.localizedDescription)") }
            }
            tempCopies.removeValue(forKey: mountPoint)
        }
    }

    // Run binary or package at path. If it's a folder (e.g., .app), we may need to run its internal executable.
    // We run exactly the provided path. If it's an app bundle and the user provided the path into the .app/Contents/MacOS/ binary, it will run fine.
    private func runExecutable(atPath fullPath: String, requireAdmin: Bool) async throws {
        // Ensure the file exists
        let fm = FileManager.default
        guard fm.fileExists(atPath: fullPath) else {
            appendLog("File not found at \(fullPath)")
            throw DMGError.runFailed("File not found: \(fullPath)")
        }

        // Make sure it's executable (chmod +x)
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fullPath)
        } catch {
            appendLog("Warning: couldn't chmod \(fullPath): \(error.localizedDescription)")
            // continue anyway
        }

        if requireAdmin {
            // Use AppleScript via osascript to prompt for credentials
            // Escape single quotes in the path
            // Notify the user and bring the app forward so the system auth dialog isn't missed.
            notifyAuthenticationWillBeRequested(message: "The app will request permission to run a command as an administrator.")
            let escaped = fullPath.replacingOccurrences(of: "\"", with: "\\\"")
            // Build do shell script command. We run the executable in background and capture exit code in a temporary file.
            // Simpler: call the command directly with administrator privileges.
            let apple = "do shell script \"\\\"\(escaped)\\\"\" with administrator privileges"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", apple]
            let out = Pipe()
            let err = Pipe()
            task.standardOutput = out
            task.standardError = err
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? "<no stderr>"
                appendLog("Admin-run failed: \(errStr)")
                throw DMGError.runFailed("Admin-run failed: \(errStr)")
            }
        } else {
            // Run normally
            let task = Process()
            task.executableURL = URL(fileURLWithPath: fullPath)
            task.arguments = []
            task.standardOutput = Pipe()
            task.standardError = Pipe()
            do {
                try task.run()
            } catch {
                appendLog("Run failed to start: \(error.localizedDescription)")
                throw DMGError.runFailed("Failed to start: \(error.localizedDescription)")
            }
            // Wait for it to finish. If it's a long-running interactive GUI installer, it may not exit quickly.
            // We wait until exit. If you want to fire-and-forget, change this behavior.
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                throw DMGError.runFailed("Process exited with \(task.terminationStatus)")
            }
        }
    }
}
