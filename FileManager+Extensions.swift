//
//  FileManager+Extensions.swift
//  Chisme
//
//  Extensions and helpers for file operations
//

import Foundation

extension FileManager {
    /// Get the contents of a directory (non-recursive, 1-level deep)
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        let contents = try contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        return contents
    }
    
    /// Check if a URL is a directory
    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        _ = fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

struct FileMatch {
    let sourceFile: URL
    let targetFolder: URL
    var moved: Bool = false
    var error: String?
    
    var displayName: String {
        sourceFile.lastPathComponent
    }
    
    var targetFolderName: String {
        targetFolder.lastPathComponent
    }
}

class FileMatcher {
    private let fileManager = FileManager.default
    
    /// Find matching folders in target directory for files in source directory
    func findMatches(sourceFolder: URL, targetFolder: URL) throws -> [FileMatch] {
        // Get files from source folder (1-level deep only)
        let sourceContents = try fileManager.contentsOfDirectory(at: sourceFolder)
        let sourceFiles = sourceContents.filter { !fileManager.isDirectory(at: $0) }
        
        // Get folders from target folder (1-level deep only)
        let targetContents = try fileManager.contentsOfDirectory(at: targetFolder)
        let targetFolders = targetContents.filter { fileManager.isDirectory(at: $0) }
        
        var matches: [FileMatch] = []
        
        // Match each source file to target folders
        for sourceFile in sourceFiles {
            let fileName = sourceFile.deletingPathExtension().lastPathComponent.lowercased()
            
            // Find matching folder (minimum 4 characters match at the start)
            if let matchedFolder = targetFolders.first(where: { folder in
                let folderName = folder.lastPathComponent.lowercased()
                return matchFileToFolder(fileName: fileName, folderName: folderName)
            }) {
                matches.append(FileMatch(sourceFile: sourceFile, targetFolder: matchedFolder))
            }
        }
        
        return matches
    }
    
    /// Check if a file name matches a folder name (minimum 4 characters at start)
    private func matchFileToFolder(fileName: String, folderName: String) -> Bool {
        let minMatchLength = 4
        
        // Ensure both have at least 4 characters
        guard fileName.count >= minMatchLength, folderName.count >= minMatchLength else {
            return false
        }
        
        // Get first 4 characters and check if folder name starts with file name prefix
        let filePrefix = String(fileName.prefix(minMatchLength))
        
        // Check if folder name starts with the file prefix
        return folderName.hasPrefix(filePrefix)
    }
    
    /// Move matched files to their target folders
    func moveFiles(matches: [FileMatch]) -> [FileMatch] {
        var results: [FileMatch] = []
        
        for var match in matches {
            let destinationURL = match.targetFolder.appendingPathComponent(match.sourceFile.lastPathComponent)
            
            do {
                // Check if file already exists at destination
                if fileManager.fileExists(atPath: destinationURL.path) {
                    // Remove existing file
                    try fileManager.removeItem(at: destinationURL)
                }
                
                // Move the file
                try fileManager.moveItem(at: match.sourceFile, to: destinationURL)
                match.moved = true
            } catch {
                match.error = error.localizedDescription
            }
            
            results.append(match)
        }
        
        return results
    }

    // MARK: - Grouping by filename similarity

    /// Compute the Levenshtein distance between two strings
    private func levenshteinDistance(_ aStr: String, _ bStr: String) -> Int {
        let a = Array(aStr)
        let b = Array(bStr)
        let n = a.count
        let m = b.count
        if n == 0 { return m }
        if m == 0 { return n }

        var prev = Array(0...m)
        var cur = [Int](repeating: 0, count: m + 1)

        for i in 1...n {
            cur[0] = i
            for j in 1...m {
                let cost = (a[i-1] == b[j-1]) ? 0 : 1
                cur[j] = min(
                    prev[j] + 1,
                    cur[j-1] + 1,
                    prev[j-1] + cost
                )
            }
            prev = cur
        }
        return cur[m]
    }

    /// Return a similarity ratio in 0...1 using Levenshtein distance normalized by max length
    private func levenshteinRatio(_ a: String, _ b: String) -> Double {
        let aa = a.lowercased()
        let bb = b.lowercased()
        let maxLen = max(aa.count, bb.count)
        if maxLen == 0 { return 1.0 }
        let dist = levenshteinDistance(aa, bb)
        return 1.0 - (Double(dist) / Double(maxLen))
    }

    /// Normalize a filename for grouping: lowercased, trimmed, collapse whitespace, strip trailing numeric suffixes like " 2" or " (2)"
    private func normalizeForGrouping(_ s: String) -> String {
        var t = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // collapse multiple whitespace
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // remove trailing numeric suffixes: " 2", " (2)", "-2" etc.
        // common patterns: space+digits at end, space + '(' digits ')'
        if let r = try? NSRegularExpression(pattern: "\\s*\\(\\d+\\)$", options: []) {
            t = r.stringByReplacingMatches(in: t, options: [], range: NSRange(location: 0, length: t.utf16.count), withTemplate: "")
        }
        if let r2 = try? NSRegularExpression(pattern: "\\s*-?\\d+$", options: []) {
            t = r2.stringByReplacingMatches(in: t, options: [], range: NSRange(location: 0, length: t.utf16.count), withTemplate: "")
        }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return t
    }

    /// Group similar (non-directory) items in the given folder by filename similarity.
    /// - Parameters:
    ///   - targetFolder: folder containing items to group (non-recursive)
    ///   - scoreThreshold: similarity threshold (0...1) above which items are considered similar. Default 0.8
    ///   - createFolders: if true, create new folders in `targetFolder` and move grouped items into them
    /// - Returns: an array of tuples (groupFolderURL, items) describing the groups. If `createFolders` is false the groupFolderURL will be a suggested name (not created).
    func groupSimilarItems(in targetFolder: URL, scoreThreshold: Double = 0.8, createFolders: Bool = true) throws -> [(URL, [URL])] {
        // List items (non-recursive)
        let contents = try fileManager.contentsOfDirectory(at: targetFolder)
        // Include both files and directories for grouping (so folders like "untitled folder 2" are considered)
        let items = contents

        // Prepare names
        struct Group {
            var repName: String
            var items: [URL]
        }

        var groups: [Group] = []

        for item in items {
            let name = item.deletingPathExtension().lastPathComponent
            let norm = normalizeForGrouping(name)
            var placed = false
            // Try to place into an existing group (greedy) using normalized representative
            for idx in groups.indices {
                let repNorm = normalizeForGrouping(groups[idx].repName)
                let score = levenshteinRatio(norm, repNorm)
                if score >= scoreThreshold {
                    groups[idx].items.append(item)
                    placed = true
                    break
                }
                // Also try against each existing member (single-linkage across members)
                if !placed {
                    for member in groups[idx].items {
                        let mname = member.deletingPathExtension().lastPathComponent
                        let mnorm = normalizeForGrouping(mname)
                        let s2 = levenshteinRatio(norm, mnorm)
                        if s2 >= scoreThreshold {
                            groups[idx].items.append(item)
                            placed = true
                            break
                        }
                    }
                }
                if placed { break }
            }
            if !placed {
                // Start a new group with this item as representative
                groups.append(Group(repName: name, items: [item]))
            }
        }

        var result: [(URL, [URL])] = []

        for g in groups {
            // Create a safe folder name based on representative
            // Use normalized representative as folder name base, stripping trailing numbers
            var folderName = normalizeForGrouping(g.repName)
            if folderName.isEmpty { folderName = "group" }
            // replace spaces and sanitize newlines
            folderName = folderName.replacingOccurrences(of: "\n", with: " ")
            folderName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
            if folderName.isEmpty { folderName = "group" }

            var folderURL = targetFolder.appendingPathComponent(folderName, isDirectory: true)
            var uniqueIndex = 1
            while fileManager.fileExists(atPath: folderURL.path) {
                // If an existing file is a directory and already contains exactly the same items, reuse it; otherwise create unique name
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDir)
                if isDir.boolValue {
                    break
                }
                folderURL = targetFolder.appendingPathComponent("\(folderName)-\(uniqueIndex)", isDirectory: true)
                uniqueIndex += 1
            }

            if createFolders {
                // Create the folder if needed
                if !fileManager.fileExists(atPath: folderURL.path) {
                    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false, attributes: nil)
                }

                // Move each item into the folder
                for item in g.items {
                    // Use standardized paths to avoid issues with trailing slashes or symlinks
                    let itemPath = item.standardizedFileURL.path
                    let folderPath = folderURL.standardizedFileURL.path

                    // If the item is the same folder as the destination, skip (already in place)
                    // Compare case-insensitively because macOS filesystem is usually case-insensitive
                    let itemPathLower = itemPath.lowercased()
                    let folderPathLower = folderPath.lowercased()
                    if itemPathLower == folderPathLower {
                        continue
                    }

                    // Safety: avoid moving a folder into one of its own descendants (case-insensitive)
                    if folderPathLower.hasPrefix(itemPathLower + "/") {
                        continue
                    }

                    let dest = folderURL.appendingPathComponent(item.lastPathComponent)
                    // If a file already exists at dest, choose a unique name (append numeric suffix)
                    if fileManager.fileExists(atPath: dest.path) {
                        var i = 1
                        let base = item.deletingPathExtension().lastPathComponent
                        let ext = item.pathExtension
                        var candidate = dest
                        while fileManager.fileExists(atPath: candidate.path) {
                            let newName = "\(base)-\(i)" + (ext.isEmpty ? "" : ".\(ext)")
                            candidate = folderURL.appendingPathComponent(newName)
                            i += 1
                        }
                        try fileManager.moveItem(at: item, to: candidate)
                    } else {
                        try fileManager.moveItem(at: item, to: dest)
                    }
                }
            }

            result.append((folderURL, g.items))
        }

        return result
    }
}
