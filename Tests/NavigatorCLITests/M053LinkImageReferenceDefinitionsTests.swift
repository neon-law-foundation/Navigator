import Foundation
import NavigatorRules
import Testing

@Suite("M053 Link Image Reference Definitions")
struct M053LinkImageReferenceDefinitionsTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M053Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Used definition passes")
    func testUsedDefinition() throws {
        let content = """
            See [text][ref] here.

            [ref]: https://example.com
            """
        let file = try makeFile(content: content + "\n")
        let rule = M053_LinkImageReferenceDefinitions()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Unused definition is flagged")
    func testUnusedDefinition() throws {
        let content = """
            No references here.

            [orphan]: https://example.com
            """
        let file = try makeFile(content: content + "\n")
        let rule = M053_LinkImageReferenceDefinitions()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].context?["label"] == "orphan")
    }

    @Test("Mixed used and unused")
    func testMixed() throws {
        let content = """
            See [text][used].

            [used]: https://example.com
            [unused]: https://other.com
            """
        let file = try makeFile(content: content + "\n")
        let rule = M053_LinkImageReferenceDefinitions()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].context?["label"] == "unused")
    }

    @Test("Shortcut use counts as reference use")
    func testShortcutUse() throws {
        let content = """
            See [ref] here.

            [ref]: https://example.com
            """
        let file = try makeFile(content: content + "\n")
        let rule = M053_LinkImageReferenceDefinitions()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Case-insensitive matching")
    func testCaseInsensitive() throws {
        let content = """
            See [text][LABEL].

            [label]: https://example.com
            """
        let file = try makeFile(content: content + "\n")
        let rule = M053_LinkImageReferenceDefinitions()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
