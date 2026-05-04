import Foundation
import NavigatorRules
import Testing

@Suite("M038 No Space In Code")
struct M038NoSpaceInCodeTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M038Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Clean code spans do not trigger")
    func testCleanCodeSpan() throws {
        let file = try makeFile(content: "Use `foo` for lookup.\n")
        let rule = M038_NoSpaceInCode()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Leading space inside backticks is flagged")
    func testLeadingSpace() throws {
        let file = try makeFile(content: "Call `  foo` here.\n")
        let rule = M038_NoSpaceInCode()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 1)
    }

    @Test("Trailing space inside backticks is flagged")
    func testTrailingSpace() throws {
        let file = try makeFile(content: "Use `foo  ` now.\n")
        let rule = M038_NoSpaceInCode()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Single balanced spaces each side are allowed")
    func testBalancedSpaces() throws {
        let file = try makeFile(content: "Use `` ` `` to escape.\n")
        let rule = M038_NoSpaceInCode()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced code blocks are skipped")
    func testFencedCodeIgnored() throws {
        let content = """
            Prose.

            ```
            `  leading`
            ```
            """
        let file = try makeFile(content: content + "\n")
        let rule = M038_NoSpaceInCode()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Empty code span is not a violation")
    func testEmptyCodeSpan() throws {
        let file = try makeFile(content: "Blah `` blah.\n")
        let rule = M038_NoSpaceInCode()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Multi-backtick fences with padding still flagged")
    func testMultiBacktick() throws {
        let file = try makeFile(content: "Use ``` foo  ``` here.\n")
        let rule = M038_NoSpaceInCode()
        // " foo  " — both sides have space, inner right side has second space → violation.
        #expect(try rule.validate(file: file).count == 1)
    }
}
