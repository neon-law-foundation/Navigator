import Foundation
import NavigatorRules
import Testing

@Suite("M054 Link Image Style")
struct M054LinkImageStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M054Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Inline link with distinct text passes")
    func testDistinctText() throws {
        let file = try makeFile(content: "See [home](https://example.com) here.\n")
        let rule = M054_LinkImageStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Link text equal to URL is flagged")
    func testTextEqualsURL() throws {
        let file = try makeFile(
            content: "See [https://example.com](https://example.com) here.\n"
        )
        let rule = M054_LinkImageStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Autolink passes")
    func testAutolink() throws {
        let file = try makeFile(content: "See <https://example.com> here.\n")
        let rule = M054_LinkImageStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Reference-style links are ignored")
    func testReferenceStyle() throws {
        let file = try makeFile(
            content: """
                See [https://example.com][ref] here.

                [ref]: https://example.com
                """
        )
        let rule = M054_LinkImageStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced code is skipped")
    func testFencedCode() throws {
        let content = """
            Prose.

            ```
            [https://x](https://x)
            ```
            """
        let file = try makeFile(content: content + "\n")
        let rule = M054_LinkImageStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
