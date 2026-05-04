import Foundation
import NavigatorRules
import Testing

@Suite("M040 Fenced Code Language")
struct M040FencedCodeLanguageTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M040Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Fenced code with language passes")
    func testWithLanguage() throws {
        let file = try makeFile(content: "```swift\ncode\n```\n")
        let rule = M040_FencedCodeLanguage()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Fence without language is a violation")
    func testNoLanguage() throws {
        let file = try makeFile(content: "```\ncode\n```\n")
        let rule = M040_FencedCodeLanguage()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M040")
    }

    @Test("Fence with info-string language + metadata passes")
    func testLanguageWithMetadata() throws {
        let file = try makeFile(content: "```ts linenums=true\ncode\n```\n")
        let rule = M040_FencedCodeLanguage()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Tilde fence without language is flagged")
    func testTildeNoLanguage() throws {
        let file = try makeFile(content: "~~~\ncode\n~~~\n")
        let rule = M040_FencedCodeLanguage()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Indented code block is not affected")
    func testIndentedIgnored() throws {
        let file = try makeFile(content: "paragraph\n\n    code\n")
        let rule = M040_FencedCodeLanguage()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
