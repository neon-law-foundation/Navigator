import Foundation
import Testing

@testable import NavigatorCLI

@Suite("Save Command")
struct SaveCommandTests {

    @Test("Throws error on non-macOS platform")
    func testNonMacOSError() async throws {
        #if !os(macOS)
        let command = SaveCommand(filePath: "test.md")
        await #expect(throws: CommandError.self) {
            try await command.run()
        }
        #endif
    }

    @Test("Errors when temp file does not exist")
    func testErrorWhenTempFileNotExists() async throws {
        #if os(macOS)
        let nonExistentFile = "/tmp/non-existent-temp-\(UUID()).md"

        #expect(throws: CommandError.self) {
            try SaveCommand.saveTempFile(to: nonExistentFile)
        }
        #endif
    }

    @Test("Errors when original file does not exist")
    func testErrorWhenOriginalFileNotExists() async throws {
        #if os(macOS)
        let tempFile = "/tmp/temp-save-test-\(UUID()).md"
        try "content".write(toFile: tempFile, atomically: true, encoding: .utf8)

        #expect(throws: CommandError.self) {
            try SaveCommand.saveTempFile(to: "/non/existent/file.md")
        }

        try? FileManager.default.removeItem(atPath: tempFile)
        #endif
    }

    @Test("Saves edited Pages content with original front matter")
    func testSavesWithFrontMatter() async throws {
        #if os(macOS)
        guard PandocConverter.isPandocInstalled() else {
            return
        }
        guard ProcessInfo.processInfo.environment["STANDARDS_PAGES_INTEGRATION"] != nil else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("save-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let originalFile = testDir.appendingPathComponent("original.md")
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let tempFile = "\(homeDir)/.standards/temp/original.pages"

        let originalContent = """
            ---
            title: Original Title
            author: John Doe
            ---

            # Old Header

            Old content here.
            """

        let editedMarkdown = """
            # New Header

            New content that was edited in TextEdit.
            """

        try originalContent.write(to: originalFile, atomically: true, encoding: .utf8)

        do {
            _ = try MarkdownEditor.ensureTempDirectory()
            let tempDOCXFile = tempFile.replacingOccurrences(of: ".pages", with: ".docx")
            try PandocConverter.convertMarkdownToDOCX(markdown: editedMarkdown, outputPath: tempDOCXFile)
            try PandocConverter.convertDOCXToPages(docxPath: tempDOCXFile, pagesPath: tempFile)
            try? FileManager.default.removeItem(atPath: tempDOCXFile)

            try SaveCommand.saveTempFile(to: originalFile.path)

            let savedContent = try String(contentsOf: originalFile, encoding: .utf8)

            #expect(savedContent.contains("---"))
            #expect(savedContent.contains("title: Original Title"))
            #expect(savedContent.contains("author: John Doe"))
            #expect(savedContent.contains("# New Header"))
            #expect(savedContent.contains("New content"))
            #expect(!savedContent.contains("Old content here."))

            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: tempFile)
        } catch {
            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: tempFile)
            throw error
        }
        #endif
    }

    @Test("Saves edited Pages content without front matter when original has none")
    func testSavesWithoutFrontMatter() async throws {
        #if os(macOS)
        guard PandocConverter.isPandocInstalled() else {
            return
        }
        guard ProcessInfo.processInfo.environment["STANDARDS_PAGES_INTEGRATION"] != nil else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("save-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let originalFile = testDir.appendingPathComponent("no-front-matter.md")
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let tempFile = "\(homeDir)/.standards/temp/no-front-matter.pages"

        let originalContent = """
            # Old Header

            Old content here.
            """

        let editedMarkdown = """
            # New Header

            New content that was edited.
            """

        try originalContent.write(to: originalFile, atomically: true, encoding: .utf8)

        do {
            _ = try MarkdownEditor.ensureTempDirectory()
            let tempDOCXFile = tempFile.replacingOccurrences(of: ".pages", with: ".docx")
            try PandocConverter.convertMarkdownToDOCX(markdown: editedMarkdown, outputPath: tempDOCXFile)
            try PandocConverter.convertDOCXToPages(docxPath: tempDOCXFile, pagesPath: tempFile)
            try? FileManager.default.removeItem(atPath: tempDOCXFile)

            try SaveCommand.saveTempFile(to: originalFile.path)

            let savedContent = try String(contentsOf: originalFile, encoding: .utf8)

            #expect(!savedContent.contains("---"))
            #expect(savedContent.contains("# New Header"))
            #expect(savedContent.contains("New content"))
            #expect(!savedContent.contains("Old content here."))

            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: tempFile)
        } catch {
            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: tempFile)
            throw error
        }
        #endif
    }

    @Test("Wraps lines at 120 characters")
    func testLineWrapping() async throws {
        #if os(macOS)
        guard PandocConverter.isPandocInstalled() else {
            return
        }
        guard ProcessInfo.processInfo.environment["STANDARDS_PAGES_INTEGRATION"] != nil else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("save-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let originalFile = testDir.appendingPathComponent("line-wrap.md")
        let tempFile = "/tmp/line-wrap.docx"

        let longLine =
            "This is a very long line that exceeds 120 characters and should be wrapped by pandoc when converting from RTF back to markdown format for proper linting compliance."

        let originalContent = """
            # Test

            Short line.
            """

        let editedMarkdown = """
            # Test

            \(longLine)
            """

        try originalContent.write(to: originalFile, atomically: true, encoding: .utf8)

        do {
            _ = try MarkdownEditor.ensureTempDirectory()
            let tempDOCXFile = tempFile.replacingOccurrences(of: ".pages", with: ".docx")
            try PandocConverter.convertMarkdownToDOCX(markdown: editedMarkdown, outputPath: tempDOCXFile)
            try PandocConverter.convertDOCXToPages(docxPath: tempDOCXFile, pagesPath: tempFile)
            try? FileManager.default.removeItem(atPath: tempDOCXFile)

            try SaveCommand.saveTempFile(to: originalFile.path)

            let savedContent = try String(contentsOf: originalFile, encoding: .utf8)
            let lines = savedContent.split(separator: "\n", omittingEmptySubsequences: false)

            for line in lines {
                #expect(
                    line.count <= 120,
                    "Line exceeds 120 characters: '\(line)' (length: \(line.count))"
                )
            }

            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: tempFile)
        } catch {
            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: tempFile)
            throw error
        }
        #endif
    }

    @Test("Converts page breaks to empty lines")
    func testPageBreakConversion() async throws {
        #if os(macOS)
        guard PandocConverter.isPandocInstalled() else {
            return
        }
        guard ProcessInfo.processInfo.environment["STANDARDS_PAGES_INTEGRATION"] != nil else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("save-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let originalFile = testDir.appendingPathComponent("pagebreak.md")
        let tempFile = "/tmp/pagebreak.docx"

        let originalContent = """
            # Test

            Content before.
            """

        let editedMarkdown = """
            # Test

            Content before.

            \\newpage

            Content after page break.
            """

        try originalContent.write(to: originalFile, atomically: true, encoding: .utf8)

        do {
            _ = try MarkdownEditor.ensureTempDirectory()
            let tempDOCXFile = tempFile.replacingOccurrences(of: ".pages", with: ".docx")
            try PandocConverter.convertMarkdownToDOCX(markdown: editedMarkdown, outputPath: tempDOCXFile)
            try PandocConverter.convertDOCXToPages(docxPath: tempDOCXFile, pagesPath: tempFile)
            try? FileManager.default.removeItem(atPath: tempDOCXFile)

            try SaveCommand.saveTempFile(to: originalFile.path)

            let savedContent = try String(contentsOf: originalFile, encoding: .utf8)

            #expect(!savedContent.contains("\\newpage"), "Page break command should be removed")
            #expect(savedContent.contains("Content before"))
            #expect(savedContent.contains("Content after page break"))

            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: tempFile)
        } catch {
            try? FileManager.default.removeItem(at: testDir)
            try? FileManager.default.removeItem(atPath: tempFile)
            throw error
        }
        #endif
    }
}
