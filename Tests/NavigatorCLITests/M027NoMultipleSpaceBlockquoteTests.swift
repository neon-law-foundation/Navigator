import Foundation
import NavigatorRules
import Testing

@Suite("M027 No Multiple Space Blockquote")
struct M027NoMultipleSpaceBlockquoteTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M027Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Single space after blockquote marker passes")
    func testSingleSpacePasses() throws {
        let file = try makeFile(content: "> text\n")
        let rule = M027_NoMultipleSpaceBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("No space after blockquote marker passes")
    func testNoSpacePasses() throws {
        let file = try makeFile(content: ">text\n")
        let rule = M027_NoMultipleSpaceBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Two spaces after blockquote marker is a violation")
    func testTwoSpacesFlagged() throws {
        let file = try makeFile(content: ">  text\n")
        let rule = M027_NoMultipleSpaceBlockquote()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M027")
        #expect(violations[0].line == 1)
    }

    @Test("Nested blockquote with single space passes")
    func testNestedSingleSpace() throws {
        let file = try makeFile(content: "> > text\n")
        let rule = M027_NoMultipleSpaceBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Nested blockquote with multiple spaces is a violation")
    func testNestedMultipleSpaces() throws {
        let file = try makeFile(content: "> >  text\n")
        let rule = M027_NoMultipleSpaceBlockquote()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Space + tab after marker is a violation")
    func testSpaceAndTabFlagged() throws {
        let file = try makeFile(content: "> \ttext\n")
        let rule = M027_NoMultipleSpaceBlockquote()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Line with unrelated > is not flagged")
    func testUnrelatedAngleBracket() throws {
        let file = try makeFile(content: "Use x > 2 when applicable.\n")
        let rule = M027_NoMultipleSpaceBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Indented blockquote (up to 3 spaces) is checked")
    func testIndentedBlockquote() throws {
        let file = try makeFile(content: "   >  text\n")
        let rule = M027_NoMultipleSpaceBlockquote()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Frontmatter is ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: >  foo
                ---
                > body
                """
        )
        let rule = M027_NoMultipleSpaceBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Blockquote-shaped lines inside fenced code are ignored")
    func testFencedCodeIgnored() throws {
        let file = try makeFile(
            content: """
                # Heading

                ```text
                >  shell prompt with two spaces
                ```
                """
        )
        let rule = M027_NoMultipleSpaceBlockquote()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
