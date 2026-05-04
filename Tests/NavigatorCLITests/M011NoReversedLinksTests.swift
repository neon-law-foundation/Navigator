import Foundation
import NavigatorRules
import Testing

@Suite("M011 No Reversed Links")
struct M011NoReversedLinksTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M011Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Reversed link is flagged")
    func testReversed() throws {
        let file = try makeFile(content: "See (label)[https://example.com] here.\n")
        let rule = M011_NoReversedLinks()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Standard link passes")
    func testStandard() throws {
        let file = try makeFile(content: "See [label](https://example.com) here.\n")
        let rule = M011_NoReversedLinks()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Code spans are ignored")
    func testInCodeSpan() throws {
        let file = try makeFile(content: "Use `(x)[y]` for reversed.\n")
        let rule = M011_NoReversedLinks()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced code blocks are ignored")
    func testFencedCode() throws {
        let content = """
            Prose.

            ```
            (x)[y]
            ```
            """
        let file = try makeFile(content: content + "\n")
        let rule = M011_NoReversedLinks()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Empty text or URL does not trigger")
    func testEmptyFields() throws {
        let file = try makeFile(content: "Use ()[url] and (text)[].\n")
        let rule = M011_NoReversedLinks()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Parenthetical followed by bracketed citation is not a link")
    func testLegitimate() throws {
        let file = try makeFile(content: "Claim (citation).[1]\n")
        let rule = M011_NoReversedLinks()
        // This is a reversed-link shape `(citation).[1]`? No — `.` sits between `)` and `[`.
        // Our detection requires `)[` adjacency — so this is OK.
        #expect(try rule.validate(file: file).isEmpty)
    }
}
