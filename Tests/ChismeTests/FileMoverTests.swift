import XCTest
import Foundation

final class FileMoverTests: XCTestCase {
    
    func testFindMatchingFolder() {
        // Create mock folder URLs
        let testFolders = [
            URL(fileURLWithPath: "/tmp/Testing"),
            URL(fileURLWithPath: "/tmp/Work Files"),
            URL(fileURLWithPath: "/tmp/Documents"),
            URL(fileURLWithPath: "/tmp/ABC")  // Too short to match anything
        ]
        
        // Test exact match on first 4 characters
        XCTAssertEqual(
            findMatchingFolder(itemName: "test_file.txt", targetFolders: testFolders)?.lastPathComponent,
            "Testing"
        )
        
        // Test case-insensitive matching
        XCTAssertEqual(
            findMatchingFolder(itemName: "TEST_file.txt", targetFolders: testFolders)?.lastPathComponent,
            "Testing"
        )
        
        XCTAssertEqual(
            findMatchingFolder(itemName: "work_document.pdf", targetFolders: testFolders)?.lastPathComponent,
            "Work Files"
        )
        
        // Test no match
        XCTAssertNil(
            findMatchingFolder(itemName: "random_file.txt", targetFolders: testFolders)
        )
        
        // Test file name too short
        XCTAssertNil(
            findMatchingFolder(itemName: "abc", targetFolders: testFolders)
        )
        
        // Test match with exactly 4 characters
        XCTAssertEqual(
            findMatchingFolder(itemName: "docu.txt", targetFolders: testFolders)?.lastPathComponent,
            "Documents"
        )
    }
    
    private func findMatchingFolder(itemName: String, targetFolders: [URL]) -> URL? {
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
