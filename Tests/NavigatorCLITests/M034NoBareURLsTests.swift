import Foundation
import NavigatorRules
import Testing

@Suite("M034 No Bare URLs")
struct M034NoBareURLsTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M034Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Bare URL in prose is a violation")
    func testBareURL() throws {
        let file = try makeFile(content: "See https://example.com for details.\n")
        let rule = M034_NoBareURLs()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M034")
        #expect(violations[0].line == 1)
    }

    @Test("Angle-bracketed URL passes")
    func testAngleBracketed() throws {
        let file = try makeFile(content: "See <https://example.com> for details.\n")
        let rule = M034_NoBareURLs()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Markdown link destination passes")
    func testLinkDestination() throws {
        let file = try makeFile(content: "See [example](https://example.com).\n")
        let rule = M034_NoBareURLs()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Image link destination passes")
    func testImageDestination() throws {
        let file = try makeFile(content: "![alt](https://example.com/img.png)\n")
        let rule = M034_NoBareURLs()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Reference-style link definition passes")
    func testReferenceLinkDefinition() throws {
        let file = try makeFile(content: "[label]: https://example.com \"title\"\n")
        let rule = M034_NoBareURLs()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Multiple bare URLs produce multiple violations")
    func testMultipleBareURLs() throws {
        let file = try makeFile(
            content: "Visit https://a.com then http://b.com for more.\n"
        )
        let rule = M034_NoBareURLs()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
    }

    @Test("http:// protocol is flagged")
    func testHTTPProtocol() throws {
        let file = try makeFile(content: "http://example.com\n")
        let rule = M034_NoBareURLs()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Frontmatter URLs are ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                source: https://example.com
                ---
                body
                """
        )
        let rule = M034_NoBareURLs()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced code block URLs are not flagged")
    func testFencedCodeIgnored() throws {
        let file = try makeFile(
            content: """
                Surrounding text.

                ```bash
                curl https://api.example.com
                ```

                More text.
                """
        )
        let rule = M034_NoBareURLs()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Indented code block URLs are not flagged")
    func testIndentedCodeIgnored() throws {
        let file = try makeFile(
            content: """
                Intro.

                    curl https://api.example.com

                Outro.
                """
        )
        let rule = M034_NoBareURLs()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Bare URL after a code block is still flagged")
    func testBareURLAfterCodeBlockStillFlagged() throws {
        let file = try makeFile(
            content: """
                Intro.

                ```
                curl https://api.example.com
                ```

                See https://example.com for more.
                """
        )
        let rule = M034_NoBareURLs()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 7)
    }
}
