//
//  FileManager+Extensions.swift
//  Chisme
//
//  Extensions and helpers for file operations
//

import Foundation

extension FileManager {
    /// Get the contents of a directory at the specified depth
    func contentsOfDirectory(at url: URL, depth: Int = 1) throws -> [URL] {
        if depth <= 0 {
            return []
        }
        
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
        fileExists(atPath: url.path, isDirectory: &isDirectory)
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
        let sourceContents = try fileManager.contentsOfDirectory(at: sourceFolder, depth: 1)
        let sourceFiles = sourceContents.filter { !fileManager.isDirectory(at: $0) }
        
        // Get folders from target folder (1-level deep only)
        let targetContents = try fileManager.contentsOfDirectory(at: targetFolder, depth: 1)
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
        
        // Get first 4+ characters and check if folder name starts with file name prefix
        let filePrefix = String(fileName.prefix(minMatchLength))
        let folderPrefix = String(folderName.prefix(minMatchLength))
        
        // Check if prefixes match
        if filePrefix == folderPrefix {
            return true
        }
        
        // Also check if folder name contains the file name prefix
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
}
