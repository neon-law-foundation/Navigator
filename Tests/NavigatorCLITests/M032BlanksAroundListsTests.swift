import Foundation
import NavigatorRules
import Testing

@Suite("M032 Blanks Around Lists")
struct M032BlanksAroundListsTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M032Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("List with blanks passes")
    func testProper() throws {
        let file = try makeFile(
            content: """
                before

                - a
                - b

                after
                """
        )
        let rule = M032_BlanksAroundLists()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Missing blank before list")
    func testMissingBefore() throws {
        let file = try makeFile(content: "before\n- a\n- b\n\nafter\n")
        let rule = M032_BlanksAroundLists()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("preceded"))
    }

    @Test("Missing blank after list")
    func testMissingAfter() throws {
        let file = try makeFile(content: "before\n\n- a\n- b\nafter\n")
        let rule = M032_BlanksAroundLists()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("followed"))
    }

    @Test("Ordered list is checked the same way")
    func testOrderedList() throws {
        let file = try makeFile(content: "before\n1. a\n2. b\n\nafter\n")
        let rule = M032_BlanksAroundLists()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("List at top of file passes")
    func testAtTop() throws {
        let file = try makeFile(content: "- a\n- b\n\nafter\n")
        let rule = M032_BlanksAroundLists()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
