import Foundation
import NavigatorRules
import Testing

@Suite("M059 Descriptive Link Text")
struct M059DescriptiveLinkTextTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M059Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("'click here' is flagged")
    func testClickHere() throws {
        let file = try makeFile(content: "See [click here](https://example.com).\n")
        let rule = M059_DescriptiveLinkText()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M059")
    }

    @Test("'read more' is flagged")
    func testReadMore() throws {
        let file = try makeFile(content: "[read more](https://example.com)\n")
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("'here', 'link', 'more' are flagged")
    func testOtherProhibited() throws {
        let file = try makeFile(
            content: """
                See [here](https://a.example).
                See [link](https://b.example).
                See [more](https://c.example).
                """
        )
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).count == 3)
    }

    @Test("Case-insensitive comparison")
    func testCaseInsensitive() throws {
        let file = try makeFile(content: "[CLICK HERE](https://example.com)\n")
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("URL-as-text is flagged")
    func testURLAsText() throws {
        let file = try makeFile(content: "[https://example.com](https://example.com)\n")
        let rule = M059_DescriptiveLinkText()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("bare URL"))
    }

    @Test("www-prefixed URL text is flagged")
    func testWWWAsText() throws {
        let file = try makeFile(content: "[www.example.com](https://example.com)\n")
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Descriptive text passes")
    func testDescriptiveText() throws {
        let file = try makeFile(
            content: "See the [project README](https://example.com) for setup.\n"
        )
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Emphasis around prohibited text is still flagged")
    func testEmphasisStripped() throws {
        let file = try makeFile(content: "[**click here**](https://example.com)\n")
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Image links are skipped")
    func testImagesSkipped() throws {
        let file = try makeFile(content: "![click here](img.png)\n")
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Reference-link text is checked")
    func testReferenceLink() throws {
        let file = try makeFile(
            content: """
                See [click here][site] for details.

                [site]: https://example.com
                """
        )
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Frontmatter is ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: "[click here](https://example.com)"
                ---

                See the [project README](https://example.com).
                """
        )
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced code is ignored")
    func testFencedCodeIgnored() throws {
        let file = try makeFile(
            content: """
                Use [the docs](https://example.com).

                ```markdown
                [click here](https://example.com)
                ```
                """
        )
        let rule = M059_DescriptiveLinkText()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
