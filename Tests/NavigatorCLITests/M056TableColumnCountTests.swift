import Foundation
import NavigatorRules
import Testing

@Suite("M056 Table Column Count")
struct M056TableColumnCountTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M056Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Matching column counts pass")
    func testConsistent() throws {
        let file = try makeFile(
            content: """
                | A | B | C |
                | - | - | - |
                | 1 | 2 | 3 |
                | 4 | 5 | 6 |
                """
        )
        let rule = M056_TableColumnCount()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Row with too few cells is flagged")
    func testTooFew() throws {
        let file = try makeFile(
            content: """
                | A | B | C |
                | - | - | - |
                | 1 | 2 |
                """
        )
        let rule = M056_TableColumnCount()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M056")
        #expect(violations[0].line == 3)
    }

    @Test("Row with too many cells is flagged")
    func testTooMany() throws {
        let file = try makeFile(
            content: """
                | A | B |
                | - | - |
                | 1 | 2 | 3 |
                """
        )
        let rule = M056_TableColumnCount()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Multiple ragged rows are all flagged")
    func testMultipleRagged() throws {
        let file = try makeFile(
            content: """
                | A | B | C |
                | - | - | - |
                | 1 | 2 |
                | 1 | 2 | 3 | 4 |
                | 1 | 2 | 3 |
                """
        )
        let rule = M056_TableColumnCount()
        #expect(try rule.validate(file: file).count == 2)
    }
}
