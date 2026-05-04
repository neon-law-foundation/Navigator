import Foundation
import NavigatorRules
import Testing

@Suite("M026 No Trailing Punctuation")
struct M026NoTrailingPunctuationTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M026Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Heading without punctuation passes")
    func testClean() throws {
        let file = try makeFile(content: "# Introduction\n")
        let rule = M026_NoTrailingPunctuation()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Trailing period is a violation")
    func testPeriod() throws {
        let file = try makeFile(content: "# Hello.\n")
        let rule = M026_NoTrailingPunctuation()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M026")
    }

    @Test("Trailing comma, semicolon, colon, exclamation all fail")
    func testAllPunctuation() throws {
        for ch in [",", ";", ":", "!"] {
            let file = try makeFile(content: "# text\(ch)\n")
            let rule = M026_NoTrailingPunctuation()
            #expect(try rule.validate(file: file).count == 1)
        }
    }

    @Test("Trailing question mark is explicitly allowed")
    func testQuestionMarkAllowed() throws {
        let file = try makeFile(content: "# What next?\n")
        let rule = M026_NoTrailingPunctuation()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Setext heading with period is flagged")
    func testSetextWithPeriod() throws {
        let file = try makeFile(content: "Title.\n======\n")
        let rule = M026_NoTrailingPunctuation()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Closed ATX with period is flagged")
    func testClosedATXWithPeriod() throws {
        let file = try makeFile(content: "# Title. #\n")
        let rule = M026_NoTrailingPunctuation()
        #expect(try rule.validate(file: file).count == 1)
    }

    @Test("Fullwidth CJK period is flagged")
    func testCJKPeriod() throws {
        let file = try makeFile(content: "# 你好\u{3002}\n")
        let rule = M026_NoTrailingPunctuation()
        #expect(try rule.validate(file: file).count == 1)
    }
}
