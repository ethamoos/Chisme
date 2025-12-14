import Foundation

/// Utility for matching files to folders based on filename prefixes
struct FileMatcher {
    
    /// Finds a matching folder in the target folders based on filename prefix.
    /// - Parameters:
    ///   - itemName: The name of the file to match
    ///   - targetFolders: Array of folder URLs to search for matches
    /// - Returns: The matching folder URL, or nil if no match is found
    static func findMatchingFolder(itemName: String, targetFolders: [URL]) -> URL? {
        // Need at least 4 characters to match
        guard itemName.count >= 4 else {
            return nil
        }
        
        let itemPrefix = String(itemName.prefix(4)).lowercased()
        
        for folder in targetFolders {
            let folderName = folder.lastPathComponent
            
            // Need at least 4 characters in folder name
            guard folderName.count >= 4 else {
                continue
            }
            
            let folderPrefix = String(folderName.prefix(4)).lowercased()
            
            // Check if first 4 characters match (case-insensitive)
            if itemPrefix == folderPrefix {
                return folder
            }
        }
        
        return nil
    }
}
