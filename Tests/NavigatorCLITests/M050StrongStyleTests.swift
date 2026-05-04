import Foundation
import NavigatorRules
import Testing

@Suite("M050 Strong Style")
struct M050StrongStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M050Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Consistent double asterisks pass")
    func testConsistentAsterisks() throws {
        let file = try makeFile(content: "Use **one** and **two** here.\n")
        let rule = M050_StrongStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Consistent double underscores pass")
    func testConsistentUnderscores() throws {
        let file = try makeFile(content: "Use __one__ and __two__ here.\n")
        let rule = M050_StrongStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Mixed ** then __ is flagged")
    func testMixedAsteriskUnderscore() throws {
        let file = try makeFile(content: "Use **first** and __second__.\n")
        let rule = M050_StrongStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].context?["expected"] == "*")
        #expect(violations[0].context?["actual"] == "_")
    }

    @Test("Single emphasis ignored by strong rule")
    func testSingleEmphasisIgnored() throws {
        let file = try makeFile(content: "Use **first** and _single_ here.\n")
        let rule = M050_StrongStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
