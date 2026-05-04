import Foundation
import NavigatorRules
import Testing

@Suite("M009 No Trailing Spaces")
struct M009NoTrailingSpacesTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M009Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Clean content passes")
    func testCleanPasses() throws {
        let file = try makeFile(content: "hello\nworld\n")
        let rule = M009_NoTrailingSpaces()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Single trailing space on content line is a violation")
    func testSingleTrailingSpace() throws {
        let file = try makeFile(content: "hello \nworld\n")
        let rule = M009_NoTrailingSpaces()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M009")
        #expect(violations[0].line == 1)
    }

    @Test("Exactly two trailing spaces on content line is allowed (hard break)")
    func testTwoTrailingSpacesAllowed() throws {
        let file = try makeFile(content: "hello  \nworld\n")
        let rule = M009_NoTrailingSpaces()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Three or more trailing spaces is a violation")
    func testThreeTrailingSpaces() throws {
        let file = try makeFile(content: "hello   \nworld\n")
        let rule = M009_NoTrailingSpaces()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 1)
    }

    @Test("Trailing tab is a violation")
    func testTrailingTab() throws {
        let file = try makeFile(content: "hello\t\nworld\n")
        let rule = M009_NoTrailingSpaces()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Blank line with trailing spaces is a violation")
    func testBlankLineWithTrailingSpaces() throws {
        let file = try makeFile(content: "hello\n  \nworld\n")
        let rule = M009_NoTrailingSpaces()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 2)
    }

    @Test("Multiple violations reported with line numbers")
    func testMultipleViolations() throws {
        let file = try makeFile(content: "a \nb\nc   \n")
        let rule = M009_NoTrailingSpaces()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
        #expect(violations.map(\.line) == [1, 3])
    }

    @Test("fix removes trailing spaces")
    func testFixRemovesTrailingSpaces() async throws {
        let file = try makeFile(content: "hello \nworld   \n")
        let rule = M009_NoTrailingSpaces()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 2)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "hello\nworld\n")
    }

    @Test("fix preserves two-space hard break")
    func testFixPreservesHardBreak() async throws {
        let file = try makeFile(content: "hello  \nworld\n")
        let rule = M009_NoTrailingSpaces()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 0)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "hello  \nworld\n")
    }

    @Test("fix trims blank-line whitespace to empty")
    func testFixTrimsBlankLine() async throws {
        let file = try makeFile(content: "a\n  \nb\n")
        let rule = M009_NoTrailingSpaces()
        _ = try await rule.fix(file: file)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "a\n\nb\n")
    }
}
