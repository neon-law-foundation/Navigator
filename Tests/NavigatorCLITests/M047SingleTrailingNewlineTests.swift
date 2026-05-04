import Foundation
import NavigatorRules
import Testing

@Suite("M047 Single Trailing Newline")
struct M047SingleTrailingNewlineTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M047Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("File ending with exactly one newline passes")
    func testSingleTrailingNewlinePasses() throws {
        let file = try makeFile(content: "hello\n")
        let rule = M047_SingleTrailingNewline()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("File with no trailing newline produces a violation")
    func testNoTrailingNewlineFails() throws {
        let file = try makeFile(content: "hello")
        let rule = M047_SingleTrailingNewline()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M047")
    }

    @Test("File with multiple trailing newlines produces a violation")
    func testMultipleTrailingNewlinesFails() throws {
        let file = try makeFile(content: "hello\n\n\n")
        let rule = M047_SingleTrailingNewline()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M047")
    }

    @Test("fix adds trailing newline when missing")
    func testFixAddsTrailingNewline() async throws {
        let file = try makeFile(content: "hello")
        let rule = M047_SingleTrailingNewline()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 1)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "hello\n")
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("fix collapses multiple trailing newlines to one")
    func testFixCollapsesTrailingNewlines() async throws {
        let file = try makeFile(content: "hello\n\n\n\n")
        let rule = M047_SingleTrailingNewline()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 1)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "hello\n")
    }

    @Test("fix is a no-op for already valid files")
    func testFixNoOp() async throws {
        let file = try makeFile(content: "hello\n")
        let rule = M047_SingleTrailingNewline()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 0)
    }

    @Test("Empty file is treated as passing")
    func testEmptyFilePasses() throws {
        let file = try makeFile(content: "")
        let rule = M047_SingleTrailingNewline()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
