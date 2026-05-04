import Foundation
import NavigatorRules
import Testing

@Suite("M058 Blanks Around Tables")
struct M058BlanksAroundTablesTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M058Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Table with blanks around passes")
    func testBlanksAround() throws {
        let file = try makeFile(
            content: """
                Some text.

                | A | B |
                | - | - |
                | 1 | 2 |

                More text.
                """
        )
        let rule = M058_BlanksAroundTables()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Table at top of document is fine")
    func testTableAtTop() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2 |

                Some text.
                """
        )
        let rule = M058_BlanksAroundTables()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Table at bottom of document is fine")
    func testTableAtBottom() throws {
        let file = try makeFile(
            content: """
                Some text.

                | A | B |
                | - | - |
                | 1 | 2 |
                """
        )
        let rule = M058_BlanksAroundTables()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Missing blank before is flagged")
    func testMissingBlankBefore() throws {
        let file = try makeFile(
            content: """
                Some text.
                | A | B |
                | - | - |
                | 1 | 2 |
                """
        )
        let rule = M058_BlanksAroundTables()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("preceded"))
    }

    @Test("Heading immediately after a table is flagged")
    func testHeadingAfterTable() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2 |
                ## Next section
                """
        )
        let rule = M058_BlanksAroundTables()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("followed"))
    }

    @Test("Paragraph after table is not flagged (GFM absorbs it)")
    func testParagraphAfterTable() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2 |
                Trailing paragraph.
                """
        )
        let rule = M058_BlanksAroundTables()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Blockquote after table is flagged")
    func testBlockquoteAfterTable() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2 |
                > quoted
                """
        )
        let rule = M058_BlanksAroundTables()
        #expect(try rule.validate(file: file).count == 1)
    }
}
