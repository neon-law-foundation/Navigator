import Foundation
import NavigatorRules
import Testing

@Suite("M018 No Missing Space ATX")
struct M018NoMissingSpaceATXTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M018Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Heading with space passes")
    func testHeadingWithSpacePasses() throws {
        let file = try makeFile(content: "# Heading\n\n## Also heading\n")
        let rule = M018_NoMissingSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Missing space after one hash is a violation")
    func testMissingSpaceH1() throws {
        let file = try makeFile(content: "#Heading\n")
        let rule = M018_NoMissingSpaceATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M018")
        #expect(violations[0].line == 1)
    }

    @Test("Missing space after multiple hashes is a violation")
    func testMissingSpaceH3() throws {
        let file = try makeFile(content: "###Heading\n")
        let rule = M018_NoMissingSpaceATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Seven or more hashes is not treated as a heading")
    func testSevenHashesIgnored() throws {
        let file = try makeFile(content: "#######Heading\n")
        let rule = M018_NoMissingSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Empty heading is allowed")
    func testEmptyHeadingAllowed() throws {
        let file = try makeFile(content: "##\n")
        let rule = M018_NoMissingSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Up to three spaces of indent allowed")
    func testIndentUpToThreeSpacesAllowed() throws {
        let file = try makeFile(content: "   #Heading\n")
        let rule = M018_NoMissingSpaceATX()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Four or more spaces is not a heading (code indent)")
    func testFourSpacesNotHeading() throws {
        let file = try makeFile(content: "    #notAHeading\n")
        let rule = M018_NoMissingSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Frontmatter lines are ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: Test
                ---
                # Real heading
                """
        )
        let rule = M018_NoMissingSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("fix inserts a single space after the hash run")
    func testFixInsertsSpace() async throws {
        let file = try makeFile(content: "#Heading\n##Sub\n")
        let rule = M018_NoMissingSpaceATX()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 2)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == "# Heading\n## Sub\n")
    }

    @Test("Hash-prefixed lines inside fenced code are not flagged or fixed")
    func testFencedCodeIgnored() async throws {
        let original = """
            # Heading

            ```python
            #not a heading
            ```

            """
        let file = try makeFile(content: original)
        let rule = M018_NoMissingSpaceATX()
        #expect(try rule.validate(file: file).isEmpty)
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 0)
        let content = try String(contentsOf: file, encoding: .utf8)
        #expect(content == original)
    }
}
