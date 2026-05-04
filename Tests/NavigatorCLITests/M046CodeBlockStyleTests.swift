import Foundation
import NavigatorRules
import Testing

@Suite("M046 Code Block Style")
struct M046CodeBlockStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M046Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("All fenced passes")
    func testAllFenced() throws {
        let file = try makeFile(content: "```swift\na\n```\n\n```swift\nb\n```\n")
        let rule = M046_CodeBlockStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("All indented passes")
    func testAllIndented() throws {
        let file = try makeFile(content: "text\n\n    first\n\ntext\n\n    second\n")
        let rule = M046_CodeBlockStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fenced then indented is a violation")
    func testMixed() throws {
        let file = try makeFile(
            content: "```swift\na\n```\n\ntext\n\n    b\n"
        )
        let rule = M046_CodeBlockStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M046")
    }

    @Test("No code blocks passes")
    func testNoCode() throws {
        let file = try makeFile(content: "no code here\n")
        let rule = M046_CodeBlockStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
