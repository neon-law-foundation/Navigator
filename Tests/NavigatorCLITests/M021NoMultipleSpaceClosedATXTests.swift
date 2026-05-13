import Foundation
import NavigatorRules
import Testing

@Suite("M021 No Multiple Space Closed ATX")
struct M021NoMultipleSpaceClosedATXTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M021Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Single-space closed ATX passes")
    func testSingleSpacePasses() throws {
        let file = try makeFile(content: "# Heading #\n")
        let rule = M021_NoMultipleSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Multiple spaces after opening is a violation")
    func testMultipleOpeningSpaces() throws {
        let file = try makeFile(content: "#  Heading #\n")
        let rule = M021_NoMultipleSpaceClosedATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M021")
    }

    @Test("Multiple spaces before closing is a violation")
    func testMultipleClosingSpaces() throws {
        let file = try makeFile(content: "# Heading  #\n")
        let rule = M021_NoMultipleSpaceClosedATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Open ATX headings are ignored")
    func testOpenATXIgnored() throws {
        let file = try makeFile(content: "#  Heading\n")
        let rule = M021_NoMultipleSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Missing spaces are not M021's concern")
    func testMissingSpacesNotFlagged() throws {
        let file = try makeFile(content: "# Heading#\n")
        let rule = M021_NoMultipleSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Frontmatter is ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: #  with  #
                ---
                # Real #
                """
        )
        let rule = M021_NoMultipleSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Closed-ATX-shaped lines inside fenced code are ignored")
    func testFencedCodeIgnored() throws {
        let file = try makeFile(
            content: """
                # Heading

                ```text
                #  body  #
                ```
                """
        )
        let rule = M021_NoMultipleSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
