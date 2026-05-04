import Foundation
import NavigatorRules
import Testing

@Suite("M003 Heading Style")
struct M003HeadingStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M003Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Consistent ATX headings pass")
    func testConsistentATX() throws {
        let file = try makeFile(content: "# H1\n\n## H2\n\n### H3\n")
        let rule = M003_HeadingStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Consistent closed ATX passes")
    func testConsistentClosedATX() throws {
        let file = try makeFile(content: "# H1 #\n\n## H2 ##\n")
        let rule = M003_HeadingStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Mixed ATX and closed ATX is a violation")
    func testMixedATXAndClosed() throws {
        let file = try makeFile(content: "# H1\n\n## H2 ##\n")
        let rule = M003_HeadingStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M003")
        #expect(violations[0].line == 3)
    }

    @Test("Setext followed by ATX level 3+ is allowed")
    func testSetextThenDeepATX() throws {
        let file = try makeFile(content: "Title\n=====\n\nSub\n-----\n\n### Deep\n")
        let rule = M003_HeadingStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Setext file with ATX h1 is a violation")
    func testSetextThenATXh1() throws {
        let file = try makeFile(content: "Title\n=====\n\n# ATX H1\n")
        let rule = M003_HeadingStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("No headings passes")
    func testNoHeadings() throws {
        let file = try makeFile(content: "just a paragraph\n")
        let rule = M003_HeadingStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
