import Foundation
import NavigatorRules
import Testing

@Suite("M004 UL Style")
struct M004ULStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M004Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("All dash markers pass")
    func testAllDashes() throws {
        let file = try makeFile(content: "- a\n- b\n- c\n")
        let rule = M004_ULStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("All asterisk markers pass")
    func testAllAsterisks() throws {
        let file = try makeFile(content: "* a\n* b\n* c\n")
        let rule = M004_ULStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Mixed markers in one list flag the deviant items")
    func testMixedWithinList() throws {
        let file = try makeFile(content: "- a\n* b\n+ c\n")
        let rule = M004_ULStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
        #expect(violations[0].line == 2)
        #expect(violations[0].context?["expected"] == "-")
        #expect(violations[0].context?["actual"] == "*")
        #expect(violations[1].line == 3)
    }

    @Test("Mixed markers across separate lists also flag")
    func testMixedAcrossLists() throws {
        let file = try makeFile(
            content: """
                - a
                - b

                * c
                * d
                """
        )
        let rule = M004_ULStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
        #expect(violations[0].line == 4)
        #expect(violations[1].line == 5)
    }

    @Test("Nested items use the same marker as top level")
    func testNestedConsistent() throws {
        let file = try makeFile(
            content: """
                - a
                  - b
                    - c
                """
        )
        let rule = M004_ULStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Nested items with different marker are flagged")
    func testNestedDifferent() throws {
        let file = try makeFile(
            content: """
                - a
                  * b
                """
        )
        let rule = M004_ULStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 2)
    }

    @Test("Ordered items do not establish or break the baseline")
    func testOrderedIgnored() throws {
        let file = try makeFile(
            content: """
                1. a
                2. b

                - c
                - d
                """
        )
        let rule = M004_ULStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
