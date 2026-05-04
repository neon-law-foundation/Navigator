import Foundation
import Testing

@testable import NavigatorCLI

@Suite("Format Command")
struct FormatCommandTests {

    @Test("Converts dash bullets to asterisk bullets")
    func testConvertsBulletMarkers() async throws {
        guard PandocConverter.isPandocInstalled() else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("format-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("bullets.md")

        let content = """
            # Test

            - First item
            - Second item
            - Third item
            """

        try content.write(to: testFile, atomically: true, encoding: .utf8)

        let command = FormatCommand(filePath: testFile.path)
        try await command.run()

        let formatted = try String(contentsOf: testFile, encoding: .utf8)

        #expect(formatted.contains("* First item"))
        #expect(formatted.contains("* Second item"))
        #expect(formatted.contains("* Third item"))
        #expect(!formatted.contains("- First item"))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("Preserves front matter")
    func testPreservesFrontMatter() async throws {
        guard PandocConverter.isPandocInstalled() else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("format-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("frontmatter.md")

        let content = """
            ---
            title: Test Document
            author: John Doe
            ---

            # Header

            - Item one
            - Item two
            """

        try content.write(to: testFile, atomically: true, encoding: .utf8)

        let command = FormatCommand(filePath: testFile.path)
        try await command.run()

        let formatted = try String(contentsOf: testFile, encoding: .utf8)

        #expect(formatted.contains("---"))
        #expect(formatted.contains("title: Test Document"))
        #expect(formatted.contains("author: John Doe"))
        #expect(formatted.contains("* Item one"))
        #expect(formatted.contains("* Item two"))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("Wraps long lines at 120 characters")
    func testWrapsLongLines() async throws {
        guard PandocConverter.isPandocInstalled() else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("format-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("longlines.md")

        let longLine =
            "This is a very long line that definitely exceeds one hundred and twenty characters and should be wrapped by pandoc when formatting the markdown file for proper compliance with linting rules."

        let content = """
            # Test

            \(longLine)
            """

        try content.write(to: testFile, atomically: true, encoding: .utf8)

        let command = FormatCommand(filePath: testFile.path)
        try await command.run()

        let formatted = try String(contentsOf: testFile, encoding: .utf8)
        let lines = formatted.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            #expect(
                line.count <= 120,
                "Line exceeds 120 characters: '\(line)' (length: \(line.count))"
            )
        }

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("Trims trailing whitespace")
    func testTrimsTrailingWhitespace() async throws {
        guard PandocConverter.isPandocInstalled() else {
            return
        }

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("format-test-\(UUID())")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("whitespace.md")

        let content = """
            # Test   \t

            Some text with trailing spaces.     \t
            """

        try content.write(to: testFile, atomically: true, encoding: .utf8)

        let command = FormatCommand(filePath: testFile.path)
        try await command.run()

        let formatted = try String(contentsOf: testFile, encoding: .utf8)
        let lines = formatted.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            #expect(
                !line.hasSuffix(" ") && !line.hasSuffix("\t"),
                "Line has trailing whitespace: '\(line)'"
            )
        }

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("Errors when file does not exist")
    func testErrorWhenFileNotExists() async throws {
        let nonExistentFile = "/tmp/non-existent-format-\(UUID()).md"

        let command = FormatCommand(filePath: nonExistentFile)
        await #expect(throws: CommandError.self) {
            try await command.run()
        }
    }
}
