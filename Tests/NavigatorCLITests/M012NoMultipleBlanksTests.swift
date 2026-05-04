import Foundation
import NavigatorRules
import Testing

@Suite("M012 No Multiple Blanks")
struct M012NoMultipleBlanksTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M012Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Single blank between paragraphs passes")
    func testSingleBlankPasses() throws {
        let file = try makeFile(content: "a\n\nb\n")
        let rule = M012_NoMultipleBlanks()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Two consecutive blanks produce one violation")
    func testTwoBlanks() throws {
        let file = try makeFile(content: "a\n\n\nb\n")
        let rule = M012_NoMultipleBlanks()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M012")
        #expect(violations[0].line == 3)
    }

    @Test("Three consecutive blanks produce two violations")
    func testThreeBlanks() throws {
        let file = try makeFile(content: "a\n\n\n\nb\n")
        let rule = M012_NoMultipleBlanks()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
        #expect(violations.map(\.line) == [3, 4])
    }

    @Test("Whitespace-only lines count as blank")
    func testWhitespaceOnlyLinesBlank() throws {
        let file = try makeFile(content: "a\n\n   \nb\n")
        let rule = M012_NoMultipleBlanks()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Trailing single newline does not flag")
    func testTrailingSingleNewlineClean() throws {
        let file = try makeFile(content: "a\nb\n")
        let rule = M012_NoMultipleBlanks()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("fix collapses runs of blank lines to one")
    func testFixCollapsesBlanks() async throws {
        let file = try makeFile(content: "a\n\n\n\nb\n")
        let rule = M012_NoMultipleBlanks()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 2)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "a\n\nb\n")
    }

    @Test("fix is a no-op for clean content")
    func testFixNoOp() async throws {
        let file = try makeFile(content: "a\n\nb\n")
        let rule = M012_NoMultipleBlanks()
        #expect(try await rule.fix(file: file) == 0)
    }
}
