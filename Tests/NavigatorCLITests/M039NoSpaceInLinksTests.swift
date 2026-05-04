import Foundation
import NavigatorRules
import Testing

@Suite("M039 No Space In Links")
struct M039NoSpaceInLinksTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M039Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Leading space in link text is flagged")
    func testLeadingSpace() throws {
        let file = try makeFile(content: "See [ label](url) here.\n")
        let rule = M039_NoSpaceInLinks()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Trailing space in link text is flagged")
    func testTrailingSpace() throws {
        let file = try makeFile(content: "See [label ](url) here.\n")
        let rule = M039_NoSpaceInLinks()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Clean link passes")
    func testCleanLink() throws {
        let file = try makeFile(content: "See [label](url) here.\n")
        let rule = M039_NoSpaceInLinks()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Image alt with spaces is flagged")
    func testImageAlt() throws {
        let file = try makeFile(content: "![ alt ](img.png)\n")
        let rule = M039_NoSpaceInLinks()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Fenced code blocks ignored")
    func testFencedCode() throws {
        let content = """
            Prose.

            ```
            [ bad ](url)
            ```
            """
        let file = try makeFile(content: content + "\n")
        let rule = M039_NoSpaceInLinks()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
