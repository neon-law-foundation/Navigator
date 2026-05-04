import Foundation
import NavigatorRules
import Testing

@Suite("M051 Link Fragments")
struct M051LinkFragmentsTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M051Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Matching fragment passes")
    func testMatchingFragment() throws {
        let content = """
            # My Heading

            See [here](#my-heading) for details.
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Missing fragment is flagged")
    func testMissingFragment() throws {
        let content = """
            # Known Heading

            Jump to [missing](#unknown-heading).
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M051")
        #expect(violations[0].context?["fragment"] == "unknown-heading")
    }

    @Test("Cross-document fragment is ignored")
    func testCrossDocumentFragment() throws {
        let content = """
            Text.

            See [there](other.md#anything).
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("#top is always allowed")
    func testTopAllowed() throws {
        let content = """
            # Heading

            [Back to top](#top)
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Punctuation is stripped from slugs")
    func testPunctuationStripped() throws {
        let content = """
            # Can I Park Here?

            See [here](#can-i-park-here).
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Underscores and hyphens preserved")
    func testUnderscoreHyphenPreserved() throws {
        let content = """
            # foo_bar-baz

            See [here](#foo_bar-baz).
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Heading with inline code is slugified correctly")
    func testHeadingWithInlineCode() throws {
        let content = """
            # Use `fetch()` to load

            See [here](#use-fetch-to-load).
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fragment in reference definition resolves")
    func testReferenceDefinitionFragment() throws {
        let content = """
            # Target

            See [here][t].

            [t]: #target
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fragment inside fenced code is ignored")
    func testFencedCodeIgnored() throws {
        let content = """
            # Good Heading

            ```markdown
            [broken](#no-such-heading)
            ```
            """
        let file = try makeFile(content: content + "\n")
        let rule = M051_LinkFragments()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("slugify exposes GitHub-style slug")
    func testSlugify() {
        #expect(M051_LinkFragments.slugify("Hello World") == "hello-world")
        #expect(M051_LinkFragments.slugify("API v2.0: Launch!") == "api-v20-launch")
        #expect(M051_LinkFragments.slugify("foo_bar-baz") == "foo_bar-baz")
        #expect(M051_LinkFragments.slugify("  spaced  ") == "--spaced--")
    }
}
