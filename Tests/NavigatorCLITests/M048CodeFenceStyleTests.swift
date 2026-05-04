import Foundation
import NavigatorRules
import Testing

@Suite("M048 Code Fence Style")
struct M048CodeFenceStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M048Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("All backtick fences pass")
    func testAllBackticks() throws {
        let file = try makeFile(content: "```swift\na\n```\n\n```ts\nb\n```\n")
        let rule = M048_CodeFenceStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("All tilde fences pass")
    func testAllTildes() throws {
        let file = try makeFile(content: "~~~swift\na\n~~~\n\n~~~ts\nb\n~~~\n")
        let rule = M048_CodeFenceStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Mixed backtick and tilde is a violation")
    func testMixed() throws {
        let file = try makeFile(content: "```swift\na\n```\n\n~~~swift\nb\n~~~\n")
        let rule = M048_CodeFenceStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M048")
    }
}
