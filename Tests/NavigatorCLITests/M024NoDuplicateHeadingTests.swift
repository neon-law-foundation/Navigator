import Foundation
import NavigatorRules
import Testing

@Suite("M024 No Duplicate Heading")
struct M024NoDuplicateHeadingTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M024Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Unique headings pass")
    func testUnique() throws {
        let file = try makeFile(content: "# Intro\n\n## Setup\n\n## Usage\n")
        let rule = M024_NoDuplicateHeading()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Two siblings with the same text fail")
    func testSiblingsDuplicate() throws {
        let file = try makeFile(content: "# Top\n\n## Foo\n\n## Foo\n")
        let rule = M024_NoDuplicateHeading()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M024")
        #expect(violations[0].line == 5)
    }

    @Test("Same text under different parents passes (siblings_only)")
    func testDifferentParents() throws {
        let file = try makeFile(
            content: """
                # Section A

                ## Foo

                # Section B

                ## Foo
                """
        )
        let rule = M024_NoDuplicateHeading()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Same text under different grandparents passes")
    func testDifferentGrandparents() throws {
        let file = try makeFile(
            content: """
                # A

                ## Setup

                ### Steps

                # B

                ## Setup

                ### Steps
                """
        )
        let rule = M024_NoDuplicateHeading()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Top-level duplicates fail")
    func testTopLevelDuplicate() throws {
        let file = try makeFile(content: "# Intro\n\n# Intro\n")
        let rule = M024_NoDuplicateHeading()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 3)
    }

    @Test("Case-insensitive comparison")
    func testCaseInsensitive() throws {
        let file = try makeFile(content: "# Top\n\n## Foo\n\n## FOO\n")
        let rule = M024_NoDuplicateHeading()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Whitespace is trimmed before comparing")
    func testWhitespaceTrimmed() throws {
        let file = try makeFile(content: "# Top\n\n## Foo\n\n##  Foo  \n")
        let rule = M024_NoDuplicateHeading()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Setext duplicates are flagged too")
    func testSetextDuplicates() throws {
        let file = try makeFile(
            content: """
                Top
                ===

                Foo
                ---

                Foo
                ---
                """
        )
        let rule = M024_NoDuplicateHeading()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Headings inside fenced code are ignored")
    func testFencedCodeIgnored() throws {
        let file = try makeFile(
            content: """
                # Top

                ## Foo

                ```markdown
                ## Foo
                ```
                """
        )
        let rule = M024_NoDuplicateHeading()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
