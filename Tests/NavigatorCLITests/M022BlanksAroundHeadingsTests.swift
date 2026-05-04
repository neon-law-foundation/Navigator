import Foundation
import NavigatorRules
import Testing

@Suite("M022 Blanks Around Headings")
struct M022BlanksAroundHeadingsTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M022Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Heading with blanks around passes")
    func testProperlySpaced() throws {
        let file = try makeFile(content: "paragraph\n\n# Heading\n\nbody\n")
        let rule = M022_BlanksAroundHeadings()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Heading at top of file with no frontmatter passes")
    func testHeadingAtTop() throws {
        let file = try makeFile(content: "# Heading\n\nbody\n")
        let rule = M022_BlanksAroundHeadings()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Heading after frontmatter passes")
    func testHeadingAfterFrontmatter() throws {
        let file = try makeFile(content: "---\ntitle: x\n---\n# Heading\n\nbody\n")
        let rule = M022_BlanksAroundHeadings()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Missing blank before heading is a violation")
    func testMissingBlankBefore() throws {
        let file = try makeFile(content: "paragraph\n# Heading\n\nbody\n")
        let rule = M022_BlanksAroundHeadings()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("preceded"))
        #expect(violations[0].line == 2)
    }

    @Test("Missing blank after heading is a violation")
    func testMissingBlankAfter() throws {
        let file = try makeFile(content: "paragraph\n\n# Heading\nbody\n")
        let rule = M022_BlanksAroundHeadings()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("followed"))
    }

    @Test("Missing both blanks produces two violations")
    func testMissingBothBlanks() throws {
        let file = try makeFile(content: "paragraph\n# Heading\nbody\n")
        let rule = M022_BlanksAroundHeadings()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
    }

    @Test("Heading at end of file passes")
    func testHeadingAtEnd() throws {
        let file = try makeFile(content: "body\n\n# Heading\n")
        let rule = M022_BlanksAroundHeadings()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
