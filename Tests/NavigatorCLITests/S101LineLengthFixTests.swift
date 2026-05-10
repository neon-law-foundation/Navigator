import Foundation
import NavigatorRules
import Testing

@Suite("S101 Line Length — auto-fix")
struct S101LineLengthFixTests {
    private func makeFile(_ content: String, name: String = "fixture.md") throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("S101Fix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(name)
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Fix returns 0 when no violations present")
    func testNoViolationsReturnsZero() async throws {
        let file = try makeFile("# Title\n\nShort line.\n")
        let rule = S101_LineLength()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 0)
    }

    @Test("Fix wraps a long paragraph and reduces violation count")
    func testWrapsLongParagraph() async throws {
        let long = String(repeating: "alpha bravo ", count: 12) + "tail"
        let file = try makeFile("# Title\n\n\(long)\n")
        let rule = S101_LineLength()

        let beforeViolations = try rule.validate(file: file).count
        #expect(beforeViolations >= 1)

        let fixed = try await rule.fix(file: file)
        #expect(fixed >= 1)

        let after = try rule.validate(file: file).count
        #expect(after == 0)

        // Round-trip the words to confirm no content was lost.
        let rewritten = try String(contentsOf: file, encoding: .utf8)
        #expect(rewritten.contains("alpha bravo"))
        #expect(rewritten.contains("tail"))
    }

    @Test("Fenced code block contents are preserved and counted as remaining violations")
    func testFencedCodePreserved() async throws {
        let longCode = String(repeating: "x", count: 200)
        let body = "# Title\n\n```swift\n\(longCode)\n```\n"
        let file = try makeFile(body)
        let rule = S101_LineLength()

        let beforeViolations = try rule.validate(file: file).count
        let fixed = try await rule.fix(file: file)

        let after = try rule.validate(file: file)
        // Code fences are not safely rewrappable; the long line stays.
        #expect(after.count == beforeViolations)
        #expect(fixed == 0)

        let rewritten = try String(contentsOf: file, encoding: .utf8)
        #expect(rewritten.contains(longCode))
    }

    @Test("Pipe table rows are preserved")
    func testTablePreserved() async throws {
        let longCell = String(repeating: "tablecellvalue ", count: 12).trimmingCharacters(in: .whitespaces)
        let row = "| a | \(longCell) | c |"
        #expect(row.count > 120)
        let body = "# Title\n\n| a | b | c |\n| - | - | - |\n\(row)\n"
        let file = try makeFile(body)
        let rule = S101_LineLength()

        _ = try await rule.fix(file: file)

        let rewritten = try String(contentsOf: file, encoding: .utf8)
        #expect(rewritten.contains(row))
    }

    @Test("Reference-style link definitions are preserved")
    func testReferenceLinkPreserved() async throws {
        let url = "https://example.com/" + String(repeating: "a", count: 200)
        let definition = "[ref]: \(url) \"title\""
        let body = "# Title\n\nSome text [link][ref].\n\n\(definition)\n"
        let file = try makeFile(body)
        let rule = S101_LineLength()

        _ = try await rule.fix(file: file)

        let rewritten = try String(contentsOf: file, encoding: .utf8)
        #expect(rewritten.contains(definition))
    }

    @Test("Fix does not crash on empty files")
    func testEmptyFile() async throws {
        let file = try makeFile("")
        let rule = S101_LineLength()
        let fixed = try await rule.fix(file: file)
        #expect(fixed == 0)
    }
}
