import Foundation
import NavigatorRules
import Testing

@Suite("M042 No Empty Links")
struct M042NoEmptyLinksTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M042Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Empty text is flagged")
    func testEmptyText() throws {
        let file = try makeFile(content: "See [](https://example.com) now.\n")
        let rule = M042_NoEmptyLinks()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Empty destination is flagged")
    func testEmptyDestination() throws {
        let file = try makeFile(content: "See [label]() now.\n")
        let rule = M042_NoEmptyLinks()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Fragment-only destination is flagged")
    func testFragmentOnly() throws {
        let file = try makeFile(content: "See [label](#) now.\n")
        let rule = M042_NoEmptyLinks()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Non-empty inline link passes")
    func testNonEmpty() throws {
        let file = try makeFile(content: "See [label](url) now.\n")
        let rule = M042_NoEmptyLinks()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Reference link with empty text is flagged")
    func testEmptyReferenceText() throws {
        let file = try makeFile(
            content: """
                See [][label] now.

                [label]: https://example.com
                """
        )
        let rule = M042_NoEmptyLinks()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Images are skipped")
    func testImagesSkipped() throws {
        // Empty alt on images belongs to M045, not M042.
        let file = try makeFile(content: "![](img.png)\n")
        let rule = M042_NoEmptyLinks()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
