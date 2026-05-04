import Foundation
import NavigatorRules
import Testing

@Suite("M001 Heading Increment")
struct M001HeadingIncrementTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M001Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Sequential increments pass")
    func testSequentialIncrements() throws {
        let file = try makeFile(content: "# H1\n\n## H2\n\n### H3\n")
        let rule = M001_HeadingIncrement()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Skipping a level is a violation")
    func testSkipLevel() throws {
        let file = try makeFile(content: "# H1\n\n### H3\n")
        let rule = M001_HeadingIncrement()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M001")
        #expect(violations[0].line == 3)
    }

    @Test("Decrease by any amount is allowed")
    func testDecreaseAllowed() throws {
        let file = try makeFile(content: "# H1\n\n## H2\n\n### H3\n\n# Back to H1\n")
        let rule = M001_HeadingIncrement()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Same level is allowed")
    func testSameLevelAllowed() throws {
        let file = try makeFile(content: "## H2\n\n## H2 again\n")
        let rule = M001_HeadingIncrement()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("First heading can be any level")
    func testFirstHeadingAnyLevel() throws {
        let file = try makeFile(content: "### Start at H3\n")
        let rule = M001_HeadingIncrement()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Setext headings are checked too")
    func testSetextChecked() throws {
        let file = try makeFile(content: "Title\n=====\n\n### Sub\n")
        let rule = M001_HeadingIncrement()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 4)
    }

    @Test("Multiple violations")
    func testMultipleViolations() throws {
        let file = try makeFile(content: "# H1\n\n### H3\n\n##### H5\n")
        let rule = M001_HeadingIncrement()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
    }
}
