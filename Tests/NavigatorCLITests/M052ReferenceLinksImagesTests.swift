import Foundation
import NavigatorRules
import Testing

@Suite("M052 Reference Links Images")
struct M052ReferenceLinksImagesTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M052Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Defined reference passes")
    func testDefinedReference() throws {
        let content = """
            See [label][ref] now.

            [ref]: https://example.com
            """
        let file = try makeFile(content: content + "\n")
        let rule = M052_ReferenceLinksImages()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Undefined full reference is flagged")
    func testUndefinedFull() throws {
        let content = """
            See [label][missing] now.
            """
        let file = try makeFile(content: content + "\n")
        let rule = M052_ReferenceLinksImages()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Undefined collapsed reference is flagged")
    func testUndefinedCollapsed() throws {
        let content = """
            See [missing][] now.
            """
        let file = try makeFile(content: content + "\n")
        let rule = M052_ReferenceLinksImages()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Inline links are ignored")
    func testInlineIgnored() throws {
        let content = "See [label](url) now.\n"
        let file = try makeFile(content: content)
        let rule = M052_ReferenceLinksImages()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Case-insensitive label matching")
    func testCaseInsensitive() throws {
        let content = """
            See [text][LABEL] now.

            [label]: https://example.com
            """
        let file = try makeFile(content: content + "\n")
        let rule = M052_ReferenceLinksImages()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
