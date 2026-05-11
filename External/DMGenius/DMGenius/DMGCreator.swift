import Foundation
import AppKit
import Combine

enum TargetChoice: String, CaseIterable, Identifiable {
    case applications = "/Applications"
    case usersShared = "/Users/Shared"
    case privateTmp = "/private/tmp"
    case userApplications = "/Users/<user>/Applications"
    case custom = "Custom"

    var id: String { self.rawValue }
}

struct DMGConfiguration {
    var sourceURL: URL? {
        didSet {
            updateVolumeName()
        }
    }
    var outputURL: URL?
    var volumeName: String = "DMGenius Volume"
    var targetChoice: TargetChoice = .applications
    var customTargetPath: String? = nil // path relative to root of dmg, e.g. "/Users/alice/Applications"
    var includeApplicationsSymlink: Bool = true

    init() {
        updateVolumeName()
    }

    private mutating func updateVolumeName() {
        if let source = sourceURL {
            let fileName = source.deletingPathExtension().lastPathComponent
            volumeName = fileName.isEmpty ? "DMGenius Volume" : fileName
        } else {
            volumeName = "DMGenius Volume"
        }
    }

    func validate() -> Result<Void, Error> {
        if sourceURL == nil { return .failure(NSError(domain: "DMGCreator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source URL is required"])) }
        if outputURL == nil { return .failure(NSError(domain: "DMGCreator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Output URL is required"])) }
        if volumeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .failure(NSError(domain: "DMGCreator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Volume name is required"])) }
        return .success(())
    }
}

protocol ProcessRunning {
    func run(_ launchPath: String, _ arguments: [String]) throws -> (output: String, error: String)
}

struct RealProcessRunner: ProcessRunning {
    func run(_ launchPath: String, _ arguments: [String]) throws -> (output: String, error: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        try proc.run()
        proc.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""

        if proc.terminationStatus != 0 {
            // Create a shell-quoted representation of the command for clearer error messages (handles spaces)
            let quotedArgs = arguments.map { arg -> String in
                if arg.contains(" ") || arg.contains("\t") || arg.contains("\n") {
                    let escaped = arg.replacingOccurrences(of: "\"", with: "\\\"")
                    return "\"\(escaped)\""
                } else {
                    return arg
                }
            }.joined(separator: " ")
            let cmdString = "\(launchPath) \(quotedArgs)"
            let userInfo: [String: Any] = [NSLocalizedDescriptionKey: "Process failed: \(cmdString)", "stdout": out, "stderr": err]
            throw NSError(domain: "ProcessRunner", code: Int(proc.terminationStatus), userInfo: userInfo)
        }

        return (out, err)
    }
}

class DMGCreator: ObservableObject {
    static let shared = DMGCreator()

    private let fileManager = FileManager.default
    private let processRunner: ProcessRunning

    @Published var isWorking: Bool = false
    @Published var progressMessage: String? = nil

    init(processRunner: ProcessRunning = RealProcessRunner()) {
        self.processRunner = processRunner
    }

    // Returns the first candidate base directory we can write to by attempting to create and remove a temp file there.
    private func firstWritableBase(from candidates: [URL]) -> URL? {
        for base in candidates {
            let testFile = base.appendingPathComponent(".dmgwritecheck_\(UUID().uuidString)")
            do {
                let data = "test".data(using: .utf8)!
                try data.write(to: testFile, options: .atomic)
                try fileManager.removeItem(at: testFile)
                return base
            } catch {
                // cannot write here, try next
            }
        }
        return nil
    }

    func createDMG(with config: DMGConfiguration, completion: @escaping (Result<URL, Error>)->Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "DMGCreator", code: 11, userInfo: [NSLocalizedDescriptionKey: "DMGCreator deallocated"])))
                return
            }
            DispatchQueue.main.async { self.isWorking = true; self.progressMessage = "Validating..." }

            switch config.validate() {
            case .failure(let err):
                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                completion(.failure(err))
                return
            case .success(): break
            }

            guard let src = config.sourceURL, let out = config.outputURL else {
                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                completion(.failure(NSError(domain: "DMGCreator", code: 9, userInfo: [NSLocalizedDescriptionKey: "Missing urls"])))
                return
            }

            // Decide a staging directory we can write to. Candidates (in order): /tmp, the user-chosen output folder (if security-scoped), and the app temp directory.
            let systemTmp = URL(fileURLWithPath: "/tmp", isDirectory: true)
            let appTmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

            // Try to start security-scoped access for the output parent early so we can use it for staging if needed.
            var accessStarted = false
            let outputParent = out.deletingLastPathComponent()
            if out.startAccessingSecurityScopedResource() {
                accessStarted = true
            }

            // We'll ensure we stop access in the outer defer after all work is done. Prepare a defer placeholder later.

            // Candidate base directories to try for staging: prefer /tmp explicitly to avoid sandboxed user folders.
            let candidates: [URL] = [systemTmp, (accessStarted ? outputParent : nil), appTmp].compactMap { $0 }
            // Try /tmp first explicitly
            var writableBase: URL? = nil
            if let _ = firstWritableBase(from: [systemTmp]) {
                writableBase = systemTmp
            } else {
                writableBase = firstWritableBase(from: candidates)
            }
            // If none writable, fail
            guard let writable = writableBase else {
                if accessStarted { out.stopAccessingSecurityScopedResource(); accessStarted = false }
                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                completion(.failure(NSError(domain: "DMGCreator", code: 12, userInfo: [NSLocalizedDescriptionKey: "Unable to find writable staging base (tried /tmp, output folder, and app temp)."])))
                return
            }
            let writableBaseFinal = writable
             
            // Determine final filename
            var finalFileName = out.lastPathComponent
            if finalFileName.isEmpty {
                finalFileName = "DMGenius.dmg"
            }
            if finalFileName.lowercased().hasSuffix(".dmg") == false { finalFileName += ".dmg" }

            var tmp: URL? = nil
            var tempOutput: URL? = nil
            var stagingCreated = false
            var lastError: Error? = nil

            for base in [writableBaseFinal] { // use only the verified writable base
                 let candidate = base.appendingPathComponent("dmg-staging-\(UUID().uuidString)")
                 do {
                     try self.fileManager.createDirectory(at: candidate, withIntermediateDirectories: true, attributes: [FileAttributeKey.posixPermissions: NSNumber(value: 0o700)])
                     tmp = candidate
                    // tempOutput next to staging so hdiutil works in same FS. Prefer the final file name (so debugging/manual hdiutil commands use the expected filename).
                     var candidateTemp = base.appendingPathComponent(finalFileName)
                     // if a file already exists at that path, avoid clobbering by creating a unique temp filename
                     if self.fileManager.fileExists(atPath: candidateTemp.path) {
                         let nameWithoutExt = (finalFileName as NSString).deletingPathExtension
                         candidateTemp = base.appendingPathComponent("\(nameWithoutExt)-temp-\(UUID().uuidString).dmg")
                     }
                     tempOutput = candidateTemp
                     stagingCreated = true
                     break
                 } catch let e {
                     lastError = e
                     // try next candidate
                 }
             }

            // If we couldn't create staging on the writable base, fail
            if !stagingCreated {
                if accessStarted { out.stopAccessingSecurityScopedResource(); accessStarted = false }
                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                let err = lastError ?? NSError(domain: "DMGCreator", code: 12, userInfo: [NSLocalizedDescriptionKey: "Unable to create staging directory on writable base: \(writableBaseFinal.path)"]) as Error
                completion(.failure(err))
                return
            }

            // We have tmp and tempOutput now; unwrap safely
            let tmpDir = tmp!
            let tempOutURL = tempOutput!

            // Ensure we stop security access after the whole operation
            defer {
                if accessStarted { out.stopAccessingSecurityScopedResource() }
            }

            // Debug: respect environment flag to preserve temp staging/output on error for debugging
            let preserveTempOnError = ProcessInfo.processInfo.environment["DMGENIUS_PRESERVE_TEMP_ON_ERROR"] == "1"

             do {
                DispatchQueue.main.async { self.progressMessage = "Building target structure..." }
                let targetRoot = try self.buildTargetStructure(in: tmpDir, config: config)

                 DispatchQueue.main.async { self.progressMessage = "Copying source..." }
                let dest = targetRoot.appendingPathComponent(src.lastPathComponent)
                 try self.copySourceToStaging(source: src, dest: dest)

                 if config.includeApplicationsSymlink && !isApplicationsInTargetPath(config: config) {
                     DispatchQueue.main.async { self.progressMessage = "Creating Applications symlink..." }
                     try self.createApplicationsSymlink(in: tmpDir)
                 }

                 DispatchQueue.main.async { self.progressMessage = "Running hdiutil..." }

                // Create output in the selected temp output location to avoid sandbox/device access issues
                try self.createCompressedReadOnlyDMG(stagingRoot: tmpDir, outputURL: tempOutURL, volumeName: config.volumeName)

                 // Attempt to move the temp DMG to the user-selected destination. Use security-scoped access if available.
                 var moved = false
                 // accessStarted already set and will be stopped by defer above

                 // If destination exists, remove it first
                 if self.fileManager.fileExists(atPath: out.path) {
                     try? self.fileManager.removeItem(at: out)
                 }

                 do {
                    try self.fileManager.moveItem(at: tempOutURL, to: out)
                     moved = true
                 } catch {
                     // If move fails, try copy & remove
                     do {
                        try self.fileManager.copyItem(at: tempOutURL, to: out)
                        try? self.fileManager.removeItem(at: tempOutURL)
                         moved = true
                     } catch let copyErr {
                         // include original hdiutil output if present
                         throw copyErr
                     }
                 }

                 DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                try? self.fileManager.removeItem(at: tmpDir)
                // if tempOutput still exists, attempt to remove it
                try? self.fileManager.removeItem(at: tempOutURL)

                 if moved {
                     completion(.success(out))
                 } else {
                     completion(.failure(NSError(domain: "DMGCreator", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to move DMG to destination"])))
                 }
             } catch {
                 DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                // Clean up only when not preserving temp files for debugging
                if !preserveTempOnError {
                    try? self.fileManager.removeItem(at: tmpDir)
                    try? self.fileManager.removeItem(at: tempOutURL)
                }

                // Wrap the error to include staging/temp paths and any process stdout/stderr if present
                var userInfo: [String: Any] = [NSLocalizedDescriptionKey: error.localizedDescription]
                userInfo["stagingPath"] = tmpDir.path
                userInfo["tempOutputPath"] = tempOutURL.path
                if let ns = error as NSError? {
                    if let stdout = ns.userInfo["stdout"] as? String { userInfo["stdout"] = stdout }
                    if let stderr = ns.userInfo["stderr"] as? String { userInfo["stderr"] = stderr }
                    // preserve original command description if present
                    if let desc = ns.userInfo[NSLocalizedDescriptionKey] as? String { userInfo[NSLocalizedDescriptionKey] = desc }
                }

                let wrapped = NSError(domain: "DMGCreator", code: 1001, userInfo: userInfo)
                completion(.failure(wrapped))
             }
         }
     }

    // Create a DMG that contains only the install-location structure (no source file copied).
    // This mirrors createDMG but omits copying the source into the staging area.
    func createStructureOnlyDMG(with config: DMGConfiguration, completion: @escaping (Result<URL, Error>)->Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "DMGCreator", code: 11, userInfo: [NSLocalizedDescriptionKey: "DMGCreator deallocated"])))
                return
            }
            DispatchQueue.main.async { self.isWorking = true; self.progressMessage = "Validating..." }

            switch config.validate() {
            case .failure(let err):
                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                completion(.failure(err))
                return
            case .success(): break
            }

            guard let out = config.outputURL else {
                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                completion(.failure(NSError(domain: "DMGCreator", code: 9, userInfo: [NSLocalizedDescriptionKey: "Output URL is required"])))
                return
            }

            // Candidate staging bases
            let systemTmp = URL(fileURLWithPath: "/tmp", isDirectory: true)
            let appTmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

            var accessStarted = false
            let outputParent = out.deletingLastPathComponent()
            if out.startAccessingSecurityScopedResource() {
                accessStarted = true
            }

            let candidates: [URL] = [systemTmp, (accessStarted ? outputParent : nil), appTmp].compactMap { $0 }
            // Prefer /tmp explicitly
            var writableBase2: URL? = nil
            if let _ = firstWritableBase(from: [systemTmp]) {
                writableBase2 = systemTmp
            } else {
                writableBase2 = firstWritableBase(from: candidates)
            }
            guard let writableBase = writableBase2 else {
                 if accessStarted { out.stopAccessingSecurityScopedResource(); accessStarted = false }
                 DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                 completion(.failure(NSError(domain: "DMGCreator", code: 12, userInfo: [NSLocalizedDescriptionKey: "Unable to find writable staging base (tried /tmp, output folder, and app temp)."])))
                 return
             }

            // Determine final filename
            var finalFileName = out.lastPathComponent
            if finalFileName.isEmpty {
                finalFileName = "DMGenius-structure.dmg"
            }
            if finalFileName.lowercased().hasSuffix(".dmg") == false { finalFileName += ".dmg" }

            var tmp: URL? = nil
            var tempOutput: URL? = nil
            var stagingCreated = false
            var lastError: Error? = nil

            for base in [writableBase] {
                let candidate = base.appendingPathComponent("dmg-staging-\(UUID().uuidString)")
                do {
                    try self.fileManager.createDirectory(at: candidate, withIntermediateDirectories: true, attributes: [FileAttributeKey.posixPermissions: NSNumber(value: 0o700)])
                    tmp = candidate
                    var candidateTemp = base.appendingPathComponent(finalFileName)
                    if self.fileManager.fileExists(atPath: candidateTemp.path) {
                        let nameWithoutExt = (finalFileName as NSString).deletingPathExtension
                        candidateTemp = base.appendingPathComponent("\(nameWithoutExt)-temp-\(UUID().uuidString).dmg")
                    }
                    tempOutput = candidateTemp
                    stagingCreated = true
                    break
                } catch let e {
                    lastError = e
                }
            }

            if !stagingCreated {
                if accessStarted { out.stopAccessingSecurityScopedResource(); accessStarted = false }
                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                let err = lastError ?? NSError(domain: "DMGCreator", code: 12, userInfo: [NSLocalizedDescriptionKey: "Unable to create staging directory on writable base: \(writableBase.path)"]) as Error
                completion(.failure(err))
                return
            }

            let tmpDir = tmp!
            let tempOutURL = tempOutput!

            defer {
                if accessStarted { out.stopAccessingSecurityScopedResource() }
            }

            let preserveTempOnError = ProcessInfo.processInfo.environment["DMGENIUS_PRESERVE_TEMP_ON_ERROR"] == "1"

            do {
                DispatchQueue.main.async { self.progressMessage = "Building target structure..." }
                // Build only the target structure in staging (no source copied)
                _ = try self.buildTargetStructure(in: tmpDir, config: config)

                 if config.includeApplicationsSymlink && !isApplicationsInTargetPath(config: config) {
                     DispatchQueue.main.async { self.progressMessage = "Creating Applications symlink..." }
                     try self.createApplicationsSymlink(in: tmpDir)
                 }

                DispatchQueue.main.async { self.progressMessage = "Running hdiutil..." }
                try self.createCompressedReadOnlyDMG(stagingRoot: tmpDir, outputURL: tempOutURL, volumeName: config.volumeName)

                // move to final
                var moved = false
                if self.fileManager.fileExists(atPath: out.path) {
                    try? self.fileManager.removeItem(at: out)
                }
                do {
                    try self.fileManager.moveItem(at: tempOutURL, to: out)
                    moved = true
                } catch {
                    try self.fileManager.copyItem(at: tempOutURL, to: out)
                    try? self.fileManager.removeItem(at: tempOutURL)
                    moved = true
                }

                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                try? self.fileManager.removeItem(at: tmpDir)
                try? self.fileManager.removeItem(at: tempOutURL)

                if moved { completion(.success(out)) }
                else { completion(.failure(NSError(domain: "DMGCreator", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to move DMG to destination"]))) }
            } catch {
                DispatchQueue.main.async { self.isWorking = false; self.progressMessage = nil }
                if !preserveTempOnError {
                    try? self.fileManager.removeItem(at: tmpDir)
                    try? self.fileManager.removeItem(at: tempOutURL)
                }
                var userInfo: [String: Any] = [NSLocalizedDescriptionKey: error.localizedDescription]
                userInfo["stagingPath"] = tmpDir.path
                userInfo["tempOutputPath"] = tempOutURL.path
                if let ns = error as NSError? {
                    if let stdout = ns.userInfo["stdout"] as? String { userInfo["stdout"] = stdout }
                    if let stderr = ns.userInfo["stderr"] as? String { userInfo["stderr"] = stderr }
                    if let desc = ns.userInfo[NSLocalizedDescriptionKey] as? String { userInfo[NSLocalizedDescriptionKey] = desc }
                }
                let wrapped = NSError(domain: "DMGCreator", code: 1002, userInfo: userInfo)
                completion(.failure(wrapped))
            }
        }
    }

    func buildTargetStructure(in stagingRoot: URL, config: DMGConfiguration) throws -> URL {
        // Determine path inside stagingRoot where the source should be placed
        var relativePath: String
        switch config.targetChoice {
        case .applications:
            relativePath = "/Applications"
        case .usersShared:
            relativePath = "/Users/Shared"
        case .privateTmp:
            relativePath = "/private/tmp"
        case .userApplications:
            let user = NSUserName()
            relativePath = "/Users/\(user)/Applications"
        case .custom:
            if let p = config.customTargetPath, !p.isEmpty {
                relativePath = p.hasPrefix("/") ? p : "/\(p)"
            } else {
                throw NSError(domain: "DMGCreator", code: 5, userInfo: [NSLocalizedDescriptionKey: "Custom path required for custom target"])
            }
        }

        // Ensure the path we append to the staging root is relative (strip any leading slash)
        let relComponent = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath

        // Create directory inside stagingRoot
        let destDir = stagingRoot.appendingPathComponent(relComponent)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
        return destDir
    }

    func copySourceToStaging(source: URL, dest: URL) throws {
        // If dest exists, remove it
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: source, to: dest)

        // If it's an app bundle or executable, ensure exec permissions
        if dest.pathExtension == "app" {
            try setPermissions(for: dest, permissions: 0o755)
        } else {
            // try to set execute bit if original had it
            let srcAttrs = try fileManager.attributesOfItem(atPath: source.path)
            if let posix = srcAttrs[.posixPermissions] as? NSNumber {
                try setPermissions(for: dest, permissions: posix.uint16Value)
            }
        }
    }

    func setPermissions(for url: URL, permissions: UInt16) throws {
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: permissions)], ofItemAtPath: url.path)
    }

    private func isApplicationsInTargetPath(config: DMGConfiguration) -> Bool {
        switch config.targetChoice {
        case .applications:
            return true
        default:
            return false
        }
    }

    func createApplicationsSymlink(in stagingRoot: URL) throws {
        let linkPath = stagingRoot.appendingPathComponent("Applications")
        if fileManager.fileExists(atPath: linkPath.path) { try fileManager.removeItem(at: linkPath) }
        try fileManager.createSymbolicLink(atPath: linkPath.path, withDestinationPath: "/Applications")
    }

    func createCompressedReadOnlyDMG(stagingRoot: URL, outputURL: URL, volumeName: String) throws {
        // hdiutil create -srcfolder <stagingRoot> -volname "Name" -ov -format UDZO <output>
        // include -verbose to capture more diagnostic output if hdiutil fails
        let args = ["create", "-verbose", "-srcfolder", stagingRoot.path, "-volname", volumeName, "-ov", "-format", "UDZO", outputURL.path]
        do {
            _ = try processRunner.run("/usr/bin/hdiutil", args)
            return
        } catch let err as NSError {
            // If UDZO failed, attempt a fallback to an uncompressed read-only image (UDRO)
            let stderr = (err.userInfo["stderr"] as? String) ?? ""
            let stdout = (err.userInfo["stdout"] as? String) ?? ""
            let msg = (err.userInfo[NSLocalizedDescriptionKey] as? String) ?? err.localizedDescription
            // Common indicator from hdiutil: "Device not configured" or DIHLDiskImageCreate() returned 6
            if stderr.contains("Device not configured") || stderr.contains("DIHLDiskImageCreate() returned 6") || msg.contains("returned 6") {
                // Try UDRO (no compression) as fallback
                let fallbackArgs = ["create", "-verbose", "-srcfolder", stagingRoot.path, "-volname", volumeName, "-ov", "-format", "UDRO", outputURL.path]
                do {
                    _ = try processRunner.run("/usr/bin/hdiutil", fallbackArgs)
                    return
                } catch let fallbackErr as NSError {
                    // If UDRO also failed, attempt the sparse-image attachment workflow as a last resort
                    // Compute approximate staging size (bytes)
                    let stagingSizeBytes = (try? self.folderSize(at: stagingRoot)) ?? 0
                    // Add padding (20%) and convert to MB, minimum 10MB
                    let sizeMB = max(10, Int(Double(stagingSizeBytes) / 1024.0 / 1024.0 * 1.2) + 1)
                    let sparseURL = outputURL.deletingPathExtension().appendingPathExtension("sparseimage")
                    let sizeArg = "\(sizeMB)m"

                    // Create sparse image
                    let createArgs = ["create", "-size", sizeArg, "-fs", "HFS+", "-volname", volumeName, "-type", "SPARSE", "-ov", sparseURL.path]
                    do {
                        _ = try processRunner.run("/usr/bin/hdiutil", createArgs)
                    } catch let createErr as NSError {
                        // include all diagnostics
                        var userInfo: [String: Any] = [:]
                        userInfo["stderr"] = (createErr.userInfo["stderr"] as? String ?? "") + "\n--- udzo stderr ---\n" + stderr
                        userInfo["stdout"] = (createErr.userInfo["stdout"] as? String ?? "") + "\n--- udzo stdout ---\n" + stdout
                        userInfo[NSLocalizedDescriptionKey] = "Failed to create sparseimage (fallback)."
                        throw NSError(domain: "ProcessRunner", code: Int(createErr.code), userInfo: userInfo)
                    }

                    // Attach sparse image to a mountpoint
                    let mountPointBase = "/Volumes"
                    let uniqueName = "DMGenius-\(UUID().uuidString)"
                    let mountPoint = URL(fileURLWithPath: mountPointBase).appendingPathComponent(uniqueName).path
                    try? FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true, attributes: nil)

                    do {
                        _ = try processRunner.run("/usr/bin/hdiutil", ["attach", "-mountpoint", mountPoint, sparseURL.path])
                    } catch let attachErr as NSError {
                        // cleanup sparse
                        try? FileManager.default.removeItem(at: sparseURL)
                        var userInfo: [String: Any] = [:]
                        userInfo["stderr"] = (attachErr.userInfo["stderr"] as? String ?? "") + "\n--- udzo stderr ---\n" + stderr
                        userInfo["stdout"] = (attachErr.userInfo["stdout"] as? String ?? "") + "\n--- udzo stdout ---\n" + stdout
                        userInfo[NSLocalizedDescriptionKey] = "Failed to attach sparseimage."
                        throw NSError(domain: "ProcessRunner", code: Int(attachErr.code), userInfo: userInfo)
                    }

                    // Copy contents of stagingRoot into the mounted sparse image
                    do {
                        try self.copyContentsOfDirectory(at: stagingRoot, to: URL(fileURLWithPath: mountPoint))
                    } catch let copyErr {
                        // attempt to detach then cleanup
                        try? processRunner.run("/usr/bin/hdiutil", ["detach", mountPoint])
                        try? FileManager.default.removeItem(at: sparseURL)
                        throw copyErr
                    }

                    // Detach
                    try? processRunner.run("/usr/bin/hdiutil", ["detach", mountPoint])

                    // Convert sparseimage to compressed UDZO
                    do {
                        _ = try processRunner.run("/usr/bin/hdiutil", ["convert", sparseURL.path, "-format", "UDZO", "-ov", "-o", outputURL.path])
                    } catch let convertErr as NSError {
                        // cleanup sparse
                        try? FileManager.default.removeItem(at: sparseURL)
                        var userInfo: [String: Any] = [:]
                        userInfo["stderr"] = (convertErr.userInfo["stderr"] as? String ?? "") + "\n--- udzo stderr ---\n" + stderr
                        userInfo["stdout"] = (convertErr.userInfo["stdout"] as? String ?? "") + "\n--- udzo stdout ---\n" + stdout
                        userInfo[NSLocalizedDescriptionKey] = "Failed to convert sparseimage to UDZO."
                        throw NSError(domain: "ProcessRunner", code: Int(convertErr.code), userInfo: userInfo)
                    }

                    // Remove sparse image
                    try? FileManager.default.removeItem(at: sparseURL)
                    return
                }
            }
            // otherwise rethrow original error
            throw err
        }
    }

    // Compute folder size in bytes
    private func folderSize(at url: URL) throws -> Int64 {
        var size: Int64 = 0
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) {
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if resourceValues.isRegularFile == true, let fileSize = resourceValues.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }

    // Copy contents of one directory into another (preserve names, copy children)
    private func copyContentsOfDirectory(at src: URL, to dst: URL) throws {
        let fm = FileManager.default
        let items = try fm.contentsOfDirectory(atPath: src.path)
        for name in items {
            let srcItem = src.appendingPathComponent(name)
            let dstItem = dst.appendingPathComponent(name)
            if fm.fileExists(atPath: dstItem.path) {
                try fm.removeItem(at: dstItem)
            }
            try fm.copyItem(at: srcItem, to: dstItem)
        }
    }
}
