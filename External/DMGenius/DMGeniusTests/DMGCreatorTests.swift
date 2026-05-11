import XCTest
@testable import DMGenius

final class DMGCreatorTests: XCTestCase {
    var creator: DMGCreator!
    let fm = FileManager.default

    override func setUp() {
        super.setUp()
        creator = DMGCreator(processRunner: TestProcessRunner())
    }

    override func tearDown() {
        creator = nil
        super.tearDown()
    }

    func testValidateConfiguration() {
        var cfg = DMGConfiguration()
        switch cfg.validate() {
        case .failure(let err):
            XCTAssertEqual(err.localizedDescription, "Source URL is required")
        case .success: XCTFail("Expected failure for missing source")
        }

        cfg.sourceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foo.app")
        switch cfg.validate() {
        case .failure(let err):
            XCTAssertEqual(err.localizedDescription, "Output URL is required")
        case .success: XCTFail("Expected failure for missing output")
        }

        cfg.outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("out.dmg")
        cfg.volumeName = " "
        switch cfg.validate() {
        case .failure(let err):
            XCTAssertEqual(err.localizedDescription, "Volume name is required")
        case .success: XCTFail("Expected failure for empty volume name")
        }

        cfg.volumeName = "Vol"
        switch cfg.validate() {
        case .failure(let err): XCTFail("Unexpected failure: \(err)")
        case .success: XCTAssertTrue(true)
        }
    }

    func testBuildTargetStructureCreatesPaths() throws {
        let staging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("staging-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true, attributes: nil)

        var cfg = DMGConfiguration()
        cfg.targetChoice = .applications

        let dest = try creator.buildTargetStructure(in: staging, config: cfg)
        XCTAssertTrue(fm.fileExists(atPath: dest.path))
        XCTAssertTrue(dest.lastPathComponent == "Applications")

        try fm.removeItem(at: staging)
    }

    func testCopySourceToStagingCopiesFile() throws {
        let staging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("staging-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true, attributes: nil)

        let src = staging.appendingPathComponent("testfile.txt")
        let data = "hello".data(using: .utf8)!
        fm.createFile(atPath: src.path, contents: data, attributes: nil)

        let destDir = staging.appendingPathComponent("dest")
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
        let dest = destDir.appendingPathComponent("testfile.txt")

        try creator.copySourceToStaging(source: src, dest: dest)

        XCTAssertTrue(fm.fileExists(atPath: dest.path))
        let copied = try Data(contentsOf: dest)
        XCTAssertEqual(copied, data)

        try fm.removeItem(at: staging)
    }
}

// MARK: - Test helpers

private struct TestProcessRunner: ProcessRunning {
    func run(_ launchPath: String, _ arguments: [String]) throws -> (output: String, error: String) {
        // Simulate success without invoking hdiutil
        return ("OK", "")
    }
}
