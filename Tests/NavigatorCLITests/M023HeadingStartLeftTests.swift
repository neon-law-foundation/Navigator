import Foundation
import NavigatorRules
import Testing

@Suite("M023 Heading Start Left")
struct M023HeadingStartLeftTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M023Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Heading flush left passes")
    func testFlushLeftPasses() throws {
        let file = try makeFile(content: "# Heading\n## Sub\n")
        let rule = M023_HeadingStartLeft()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Indented heading is a violation")
    func testIndentedHeading() throws {
        let file = try makeFile(content: "  # Heading\n")
        let rule = M023_HeadingStartLeft()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M023")
        #expect(violations[0].line == 1)
    }

    @Test("One space of indent is a violation")
    func testOneSpaceIndent() throws {
        let file = try makeFile(content: " # Heading\n")
        let rule = M023_HeadingStartLeft()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Four or more spaces is not a heading (code block)")
    func testFourSpacesNotHeading() throws {
        let file = try makeFile(content: "    # Looks like indented code\n")
        let rule = M023_HeadingStartLeft()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Closed ATX with indent is a violation")
    func testIndentedClosedATX() throws {
        let file = try makeFile(content: "  ## Heading ##\n")
        let rule = M023_HeadingStartLeft()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("fix removes heading indent")
    func testFixRemovesIndent() async throws {
        let file = try makeFile(content: "  # Heading\n   ## Sub ##\n")
        let rule = M023_HeadingStartLeft()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 2)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "# Heading\n## Sub ##\n")
    }

    @Test("Frontmatter is ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: "  # Not a heading"
                ---
                # Real
                """
        )
        let rule = M023_HeadingStartLeft()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Hash-prefixed line inside a fenced code block is not a heading")
    func testFencedCodeHashLineNotFlagged() throws {
        let file = try makeFile(
            content: """
                # Heading

                ```bash
                  # A shell comment with leading whitespace
                echo hello
                ```
                """
        )
        let rule = M023_HeadingStartLeft()
        #expect(try rule.validate(file: file).isEmpty)
    }

    // Reproduces the issue: an indented fenced code block inside a list item
    // contains a `#`-prefixed line. The previous implementation flagged that
    // line and `--fix` silently stripped its leading whitespace, corrupting
    // the source.
    @Test("fix leaves fenced-code body untouched")
    func testFixLeavesFenceContentsUntouched() async throws {
        let original = """
            # Minimal repro

            1. Some setup step:

               ```bash
               # A shell comment indented to match the list-item code block
               echo hello
               ```

            """
        let file = try makeFile(content: original)
        let rule = M023_HeadingStartLeft()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 0)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == original)
    }

    @Test("Indented heading outside a fence is still fixed")
    func testIndentedHeadingOutsideFenceStillFixed() async throws {
        let file = try makeFile(
            content: """
                  # Indented heading

                ```bash
                  # Indented shell comment
                ```
                """
        )
        let rule = M023_HeadingStartLeft()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 1)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(
            content == """
                # Indented heading

                ```bash
                  # Indented shell comment
                ```
                """
        )
    }
}
