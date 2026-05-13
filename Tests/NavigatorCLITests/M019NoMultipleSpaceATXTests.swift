import Foundation
import NavigatorRules
import Testing

@Suite("M019 No Multiple Space ATX")
struct M019NoMultipleSpaceATXTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M019Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Single space passes")
    func testSingleSpacePasses() throws {
        let file = try makeFile(content: "# Heading\n")
        let rule = M019_NoMultipleSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Two spaces after hash is a violation")
    func testTwoSpacesFlagged() throws {
        let file = try makeFile(content: "#  Heading\n")
        let rule = M019_NoMultipleSpaceATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M019")
        #expect(violations[0].line == 1)
    }

    @Test("Three spaces after hash is a violation")
    func testThreeSpacesFlagged() throws {
        let file = try makeFile(content: "##   Sub\n")
        let rule = M019_NoMultipleSpaceATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Missing space after hash is not M019's concern")
    func testMissingSpaceNotFlagged() throws {
        let file = try makeFile(content: "#Heading\n")
        let rule = M019_NoMultipleSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Non-headings are ignored")
    func testNonHeadingsIgnored() throws {
        let file = try makeFile(content: "plain  text\n")
        let rule = M019_NoMultipleSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("fix collapses to a single space")
    func testFixCollapsesSpaces() async throws {
        let file = try makeFile(content: "#   Heading\n##  Sub\n")
        let rule = M019_NoMultipleSpaceATX()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 2)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "# Heading\n## Sub\n")
    }

    @Test("Frontmatter is ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: #  Not a heading
                ---
                # Real
                """
        )
        let rule = M019_NoMultipleSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced code lines with multiple spaces after `#` are not flagged or fixed")
    func testFencedCodeIgnored() async throws {
        let original = """
            # Heading

            ```python
            #  shell-style comment with two spaces
            ```

            """
        let file = try makeFile(content: original)
        let rule = M019_NoMultipleSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 0)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == original)
    }
}
