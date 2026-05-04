import Foundation
import NavigatorRules
import Testing

@Suite("M007 UL Indent")
struct M007ULIndentTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M007Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Top-level items at column 1 pass")
    func testFlatList() throws {
        let file = try makeFile(content: "- a\n- b\n- c\n")
        let rule = M007_ULIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Two-space nesting passes")
    func testCorrectNesting() throws {
        let file = try makeFile(
            content: """
                - a
                  - b
                    - c
                """
        )
        let rule = M007_ULIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Four-space nesting at depth 1 flags")
    func testFourSpaceIndent() throws {
        let file = try makeFile(
            content: """
                - a
                    - b
                """
        )
        let rule = M007_ULIndent()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 2)
        #expect(violations[0].context?["expected"] == "2")
        #expect(violations[0].context?["actual"] == "4")
    }

    @Test("Three-space indent at depth 1 flags")
    func testThreeSpaceIndent() throws {
        let file = try makeFile(
            content: """
                - a
                   - b
                """
        )
        let rule = M007_ULIndent()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Ordered list items are not checked")
    func testOrderedIgnored() throws {
        let file = try makeFile(
            content: """
                1. a
                   1. b
                """
        )
        let rule = M007_ULIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Three deep levels all correct pass")
    func testThreeLevelsCorrect() throws {
        let file = try makeFile(
            content: """
                - a
                  - b
                    - c
                      - d
                """
        )
        let rule = M007_ULIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Unordered child of single-digit ordered parent indents three spaces")
    func testULUnderSingleDigitOL() throws {
        let file = try makeFile(
            content: """
                1. parent
                   - child
                   - child
                """
        )
        let rule = M007_ULIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Unordered child of double-digit ordered parent indents four spaces")
    func testULUnderDoubleDigitOL() throws {
        let file = try makeFile(
            content: """
                10. parent
                    - child
                """
        )
        let rule = M007_ULIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Unordered child of ordered parent with too-much indent flags")
    func testULUnderOLWrongIndent() throws {
        let file = try makeFile(
            content: """
                1. parent
                    - child
                """
        )
        let rule = M007_ULIndent()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 2)
        #expect(violations[0].context?["expected"] == "3")
        #expect(violations[0].context?["actual"] == "4")
    }

    @Test("Deepest level at bad indent flags only that item")
    func testOnlyBadItemFlagged() throws {
        let file = try makeFile(
            content: """
                - a
                  - b
                     - c
                """
        )
        let rule = M007_ULIndent()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 3)
    }
}
