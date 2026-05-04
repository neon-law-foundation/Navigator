import Foundation
import NavigatorRules
import Testing

@Suite("M020 No Missing Space Closed ATX")
struct M020NoMissingSpaceClosedATXTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M020Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Properly-spaced closed ATX heading passes")
    func testProperClosedATXPasses() throws {
        let file = try makeFile(content: "# Heading #\n## Sub ##\n")
        let rule = M020_NoMissingSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Open ATX is not flagged")
    func testOpenATXNotFlagged() throws {
        let file = try makeFile(content: "# Heading\n## Sub\n")
        let rule = M020_NoMissingSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Missing space before closing hashes is a violation")
    func testMissingSpaceBeforeClose() throws {
        let file = try makeFile(content: "# Heading#\n")
        let rule = M020_NoMissingSpaceClosedATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M020")
        #expect(violations[0].line == 1)
    }

    @Test("Missing space after opening hashes in closed ATX is a violation")
    func testMissingSpaceAfterOpen() throws {
        let file = try makeFile(content: "#Heading #\n")
        let rule = M020_NoMissingSpaceClosedATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Missing both opening and closing spaces is a violation")
    func testMissingBothSpaces() throws {
        let file = try makeFile(content: "#Heading#\n")
        let rule = M020_NoMissingSpaceClosedATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Line that is only hashes is not flagged")
    func testOnlyHashesNotFlagged() throws {
        let file = try makeFile(content: "####\n")
        let rule = M020_NoMissingSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Trailing whitespace after closing hashes is fine")
    func testTrailingWhitespaceFine() throws {
        let file = try makeFile(content: "# Heading #   \n")
        let rule = M020_NoMissingSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Frontmatter is ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: foo#bar#
                ---
                # Real #
                """
        )
        let rule = M020_NoMissingSpaceClosedATX()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
