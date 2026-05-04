import Foundation
import NavigatorRules
import Testing

@Suite("M045 No Alt Text")
struct M045NoAltTextTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M045Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Empty inline alt is flagged")
    func testEmptyInline() throws {
        let file = try makeFile(content: "![](img.png)\n")
        let rule = M045_NoAltText()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Non-empty inline alt passes")
    func testNonEmptyInline() throws {
        let file = try makeFile(content: "![logo](img.png)\n")
        let rule = M045_NoAltText()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Full reference image with empty alt is flagged")
    func testReferenceEmptyAlt() throws {
        let file = try makeFile(
            content: """
                ![][logo]

                [logo]: img.png
                """
        )
        let rule = M045_NoAltText()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Collapsed reference image uses label as alt")
    func testCollapsedReference() throws {
        let file = try makeFile(
            content: """
                ![logo][]

                [logo]: img.png
                """
        )
        let rule = M045_NoAltText()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Regular links are skipped")
    func testLinksSkipped() throws {
        let file = try makeFile(content: "[](url)\n")
        let rule = M045_NoAltText()
        // That's M042, not M045.
        #expect(try rule.validate(file: file).isEmpty)
    }
}
