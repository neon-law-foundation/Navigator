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
}
