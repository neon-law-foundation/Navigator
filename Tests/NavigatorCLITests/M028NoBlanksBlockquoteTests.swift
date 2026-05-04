import Foundation
import NavigatorRules
import Testing

@Suite("M028 No Blanks Blockquote")
struct M028NoBlanksBlockquoteTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M028Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Clean block quote passes")
    func testCleanBlockquote() throws {
        let file = try makeFile(content: "> line one\n> line two\n")
        let rule = M028_NoBlanksBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Blank line between two block quotes is a violation")
    func testBlankBetweenBlockquotes() throws {
        let file = try makeFile(content: "> first\n\n> second\n")
        let rule = M028_NoBlanksBlockquote()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M028")
        #expect(violations[0].line == 2)
    }

    @Test("Non-blockquote content between blockquotes is not flagged")
    func testContentBetween() throws {
        let file = try makeFile(content: "> first\n\nparagraph\n\n> second\n")
        let rule = M028_NoBlanksBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Blockquote followed by paragraph is fine")
    func testBlockquoteThenParagraph() throws {
        let file = try makeFile(content: "> first\n\nparagraph\n")
        let rule = M028_NoBlanksBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
