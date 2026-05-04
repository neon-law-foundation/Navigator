import Foundation
import NavigatorRules
import Testing

@Suite("M060 Table Column Style")
struct M060TableColumnStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M060Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Tight style passes")
    func testTight() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2 |
                """
        )
        let rule = M060_TableColumnStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Compact style passes")
    func testCompact() throws {
        let file = try makeFile(
            content: """
                |A|B|
                |-|-|
                |1|2|
                """
        )
        let rule = M060_TableColumnStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Aligned style with padded cells passes")
    func testAligned() throws {
        let file = try makeFile(
            content: """
                | Header | Header |
                | ------ | ------ |
                | Cell   | Cell   |
                """
        )
        let rule = M060_TableColumnStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Mixed compact + tight is flagged")
    func testMixedStyles() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                |1|2|
                """
        )
        let rule = M060_TableColumnStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M060")
    }

    @Test("Misaligned padded table is flagged")
    func testMisalignedPadded() throws {
        let file = try makeFile(
            content: """
                | Header | Header |
                |  ----- |  ----- |
                | Short  | A long cell |
                """
        )
        let rule = M060_TableColumnStyle()
        // Row 1 pipes at offsets 0/9/18; row 2 at 0/9/18; row 3 at 0/9/22.
        // Aligned fails (row 3 differs); tight fails (row 2 has 2-space leading padding);
        // compact fails (everything is padded). Flag.
        #expect(try rule.validate(file: file).count == 1)
    }
}
