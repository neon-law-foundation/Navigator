import Foundation
import NavigatorRules
import Testing

@Suite("M055 Table Pipe Style")
struct M055TablePipeStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M055Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Both-pipe consistent table passes")
    func testConsistentBothPipe() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2 |
                """
        )
        let rule = M055_TablePipeStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Trailing-only first table sets the pattern; matching second passes")
    func testTrailingOnlyConsistent() throws {
        let file = try makeFile(
            content: """
                A | B |
                - | - |
                1 | 2 |

                X | Y |
                - | - |
                a | b |
                """
        )
        let rule = M055_TablePipeStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Row missing trailing pipe in a both-pipe table is flagged")
    func testInconsistentRow() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2
                """
        )
        let rule = M055_TablePipeStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 3)
    }

    @Test("Second table that switches pipe style is flagged")
    func testInconsistentBetweenTables() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2 |

                A | B
                - | -
                1 | 2
                """
        )
        let rule = M055_TablePipeStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 3)
    }

    @Test("No tables, no violations")
    func testNoTables() throws {
        let file = try makeFile(content: "Just a paragraph.\n")
        let rule = M055_TablePipeStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
