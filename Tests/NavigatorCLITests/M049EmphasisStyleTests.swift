import Foundation
import NavigatorRules
import Testing

@Suite("M049 Emphasis Style")
struct M049EmphasisStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M049Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Consistent asterisks pass")
    func testConsistentAsterisks() throws {
        let file = try makeFile(content: "First *one* and *two* and *three*.\n")
        let rule = M049_EmphasisStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Consistent underscores pass")
    func testConsistentUnderscores() throws {
        let file = try makeFile(content: "First _one_ and _two_ and _three_.\n")
        let rule = M049_EmphasisStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Mixed asterisks then underscore is flagged")
    func testMixedAsteriskUnderscore() throws {
        let file = try makeFile(content: "Use *first* and then _second_.\n")
        let rule = M049_EmphasisStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].context?["expected"] == "*")
        #expect(violations[0].context?["actual"] == "_")
    }

    @Test("Strong emphasis is not considered by M049")
    func testStrongIgnored() throws {
        let file = try makeFile(content: "First *one* then **strong**.\n")
        let rule = M049_EmphasisStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Intraword underscore is not emphasis")
    func testIntrawordUnderscore() throws {
        // First emphasis is `*one*` with `*` baseline. `foo_bar_baz` is not emphasis — no flag.
        let file = try makeFile(content: "See *one* and foo_bar_baz.\n")
        let rule = M049_EmphasisStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced code blocks are skipped")
    func testFencedCodeIgnored() throws {
        let content = """
            *One* here.

            ```
            _mismatch_
            ```

            *Two* also.
            """
        let file = try makeFile(content: content + "\n")
        let rule = M049_EmphasisStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
