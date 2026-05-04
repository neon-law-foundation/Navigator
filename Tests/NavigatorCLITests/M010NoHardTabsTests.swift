import Foundation
import NavigatorRules
import Testing

@Suite("M010 No Hard Tabs")
struct M010NoHardTabsTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M010Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Clean content passes")
    func testCleanPasses() throws {
        let file = try makeFile(content: "hello\nworld\n")
        let rule = M010_NoHardTabs()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("A tab anywhere in a line is a violation")
    func testTabProducesViolation() throws {
        let file = try makeFile(content: "hello\tworld\n")
        let rule = M010_NoHardTabs()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M010")
        #expect(violations[0].line == 1)
    }

    @Test("Leading-tab indent is a violation")
    func testLeadingTab() throws {
        let file = try makeFile(content: "\thello\n")
        let rule = M010_NoHardTabs()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Multiple lines with tabs each produce one violation")
    func testMultipleLinesWithTabs() throws {
        let file = try makeFile(content: "a\tb\nc\nd\te\n")
        let rule = M010_NoHardTabs()
        let violations = try rule.validate(file: file)
        #expect(violations.map(\.line) == [1, 3])
    }

    @Test("fix replaces tabs with four spaces")
    func testFixReplacesTabsWithSpaces() async throws {
        let file = try makeFile(content: "a\tb\n\tindent\n")
        let rule = M010_NoHardTabs()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 2)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "a    b\n    indent\n")
    }

    @Test("fix is a no-op for tab-free content")
    func testFixNoOp() async throws {
        let file = try makeFile(content: "hello\n")
        let rule = M010_NoHardTabs()
        #expect(try await rule.fix(file: file) == 0)
    }
}
