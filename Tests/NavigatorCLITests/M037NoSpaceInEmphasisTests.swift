import Foundation
import NavigatorRules
import Testing

@Suite("M037 No Space In Emphasis")
struct M037NoSpaceInEmphasisTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M037Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Leading space inside single-asterisk emphasis is flagged")
    func testLeadingSpaceSingleAsterisk() throws {
        let file = try makeFile(content: "This is * text* here.\n")
        let rule = M037_NoSpaceInEmphasis()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M037")
        #expect(violations[0].line == 1)
    }

    @Test("Trailing space inside underscore emphasis is flagged")
    func testTrailingSpaceUnderscore() throws {
        let file = try makeFile(content: "Some _text _ here.\n")
        let rule = M037_NoSpaceInEmphasis()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Both-sides spaces inside strong emphasis is flagged")
    func testBothSidesStrong() throws {
        let file = try makeFile(content: "Leading ** text ** trailing.\n")
        let rule = M037_NoSpaceInEmphasis()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Well-formed emphasis does not trigger")
    func testValidEmphasis() throws {
        let file = try makeFile(
            content: "This *emphasis* and **strong** and _under_ and __strong2__ all fine.\n"
        )
        let rule = M037_NoSpaceInEmphasis()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Content inside code spans is skipped")
    func testCodeSpanIgnored() throws {
        let file = try makeFile(content: "Call `* x *` with backticks.\n")
        let rule = M037_NoSpaceInEmphasis()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced code blocks are skipped")
    func testFencedCodeIgnored() throws {
        let content = """
            Prose here.

            ```
            * x *
            ```

            More prose.
            """
        let file = try makeFile(content: content + "\n")
        let rule = M037_NoSpaceInEmphasis()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Frontmatter is skipped")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: "* a *"
                ---
                body
                """
        )
        let rule = M037_NoSpaceInEmphasis()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Horizontal rules are not emphasis")
    func testHRNotEmphasis() throws {
        let file = try makeFile(content: "before\n\n***\n\nafter\n")
        let rule = M037_NoSpaceInEmphasis()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Multiple violations on the same line are reported separately")
    func testMultipleOnSameLine() throws {
        let file = try makeFile(content: "First * one * and second * two * here.\n")
        let rule = M037_NoSpaceInEmphasis()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
    }

    @Test("Escaped asterisks are ignored")
    func testEscapedAsterisks() throws {
        let file = try makeFile(content: #"Escaped \* x \* here."# + "\n")
        let rule = M037_NoSpaceInEmphasis()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Bare asterisk pair without content is ignored")
    func testEmptyInside() throws {
        let file = try makeFile(content: "Nothing ** ** here.\n")
        let rule = M037_NoSpaceInEmphasis()
        // Empty content between markers doesn't look like intended emphasis.
        #expect(try rule.validate(file: file).isEmpty)
    }
}
