import XCTest
import Foundation
@testable import Chisme

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
            FileMatcher.findMatchingFolder(itemName: "test_file.txt", targetFolders: testFolders)?.lastPathComponent,
            "Testing"
        )
        
        // Test case-insensitive matching
        XCTAssertEqual(
            FileMatcher.findMatchingFolder(itemName: "TEST_file.txt", targetFolders: testFolders)?.lastPathComponent,
            "Testing"
        )
        
        XCTAssertEqual(
            FileMatcher.findMatchingFolder(itemName: "work_document.pdf", targetFolders: testFolders)?.lastPathComponent,
            "Work Files"
        )
        
        // Test no match
        XCTAssertNil(
            FileMatcher.findMatchingFolder(itemName: "random_file.txt", targetFolders: testFolders)
        )
        
        // Test file name too short
        XCTAssertNil(
            FileMatcher.findMatchingFolder(itemName: "abc", targetFolders: testFolders)
        )
        
        // Test match with exactly 4 characters
        XCTAssertEqual(
            FileMatcher.findMatchingFolder(itemName: "docu.txt", targetFolders: testFolders)?.lastPathComponent,
            "Documents"
        )
    }
}
