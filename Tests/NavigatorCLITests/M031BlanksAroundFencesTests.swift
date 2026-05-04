import Foundation
import NavigatorRules
import Testing

@Suite("M031 Blanks Around Fences")
struct M031BlanksAroundFencesTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M031Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Fence with blanks around passes")
    func testProperlySpaced() throws {
        let file = try makeFile(
            content: """
                before

                ```swift
                code
                ```

                after
                """
        )
        let rule = M031_BlanksAroundFences()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fence at top of file passes")
    func testAtTop() throws {
        let file = try makeFile(content: "```\ncode\n```\n\nafter\n")
        let rule = M031_BlanksAroundFences()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Missing blank before fence")
    func testMissingBlankBefore() throws {
        let file = try makeFile(content: "before\n```\ncode\n```\n\nafter\n")
        let rule = M031_BlanksAroundFences()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("preceded"))
    }

    @Test("Missing blank after fence")
    func testMissingBlankAfter() throws {
        let file = try makeFile(content: "before\n\n```\ncode\n```\nafter\n")
        let rule = M031_BlanksAroundFences()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message.contains("followed"))
    }
}
