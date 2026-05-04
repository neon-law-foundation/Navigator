import Foundation
import Testing

@testable import NavigatorCLI

@Suite("Edit Command")
struct EditCommandTests {

    @Test("Throws error on non-macOS platform")
    func testNonMacOSError() async throws {
        #if !os(macOS)
        let command = EditCommand(filePath: "test.md")
        await #expect(throws: CommandError.self) {
            try await command.run()
        }
        #endif
    }

    @Test("Creates temp Pages file with transformed content")
    func testCreatesTempFile() async throws {
        #if os(macOS)
        guard PandocConverter.isPandocInstalled() else {
            return
        }
        guard ProcessInfo.processInfo.environment["STANDARDS_PAGES_INTEGRATION"] != nil else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("edit-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("source-file-test-edit.md")
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let expectedTempFile = "\(homeDir)/.standards/temp/source-file-test-edit.pages"

        let content = """
            ---
            title: Test
            ---

            # Header

            This is a paragraph
            that spans multiple
            lines.
            """

        try content.write(to: testFile, atomically: true, encoding: .utf8)

        do {
            let tempPath = try EditCommand.createTempFile(from: testFile.path)

            #expect(tempPath == expectedTempFile)
            #expect(FileManager.default.fileExists(atPath: expectedTempFile))
            #expect(tempPath.hasSuffix(".pages"))

            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: expectedTempFile)
        } catch {
            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: expectedTempFile)
            throw error
        }
        #endif
    }

    @Test("Overwrites existing temp file")
    func testOverwritesExistingTempFile() async throws {
        #if os(macOS)
        guard PandocConverter.isPandocInstalled() else {
            return
        }
        guard ProcessInfo.processInfo.environment["STANDARDS_PAGES_INTEGRATION"] != nil else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("edit-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("source-overwrite-test.md")
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let expectedTempFile = "\(homeDir)/.standards/temp/source-overwrite-test.pages"

        let content = """
            # New Content
            """

        try content.write(to: testFile, atomically: true, encoding: .utf8)
        try "old rtf content".write(toFile: expectedTempFile, atomically: true, encoding: .utf8)

        do {
            let tempPath = try EditCommand.createTempFile(from: testFile.path)

            #expect(FileManager.default.fileExists(atPath: tempPath))
            #expect(tempPath == expectedTempFile)

            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: expectedTempFile)
        } catch {
            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: expectedTempFile)
            throw error
        }
        #endif
    }

    @Test("Errors when original file does not exist")
    func testErrorWhenFileNotExists() async throws {
        #if os(macOS)
        let nonExistentFile = "/tmp/non-existent-file-\(UUID()).md"

        #expect(throws: CommandError.self) {
            _ = try EditCommand.createTempFile(from: nonExistentFile)
        }
        #endif
    }
}
