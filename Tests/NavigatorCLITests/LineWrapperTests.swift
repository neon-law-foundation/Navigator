import Foundation
import NavigatorRules
import Testing

@Suite("LineWrapper")
struct LineWrapperTests {
    private static let max = 120

    @Test("Short lines are unchanged")
    func testShortLinesUnchanged() {
        let input = "# Heading\n\nA short paragraph.\n"
        #expect(LineWrapper.wrap(input, maxLength: Self.max) == input)
    }

    @Test("Long paragraph wraps at the last whitespace ≤ maxLength")
    func testLongParagraphWraps() {
        // 11 occurrences of "alpha bravo " (12 chars each, 132 total) + final word.
        let long = String(repeating: "alpha bravo ", count: 11) + "charlie"
        let wrapped = LineWrapper.wrap(long, maxLength: Self.max)

        let lines = wrapped.components(separatedBy: "\n")
        #expect(lines.count >= 2)
        for line in lines {
            #expect(line.count <= Self.max)
        }
        // Round-trip the words to confirm no content was lost.
        let originalWords = long.split(separator: " ").map(String.init)
        let wrappedWords = wrapped.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
        #expect(originalWords == wrappedWords)
    }

    @Test("Lines inside fenced code blocks are preserved verbatim")
    func testFencedCodeBlockPreserved() {
        let longCode = String(repeating: "x", count: 200)
        let input = "Before.\n```swift\n\(longCode)\n```\nAfter.\n"
        let output = LineWrapper.wrap(input, maxLength: Self.max)
        #expect(output.contains(longCode))
        #expect(output == input)
    }

    @Test("Tilde-fenced code blocks are preserved")
    func testTildeFencedCodeBlockPreserved() {
        let longCode = String(repeating: "y", count: 150)
        let input = "Intro.\n~~~\n\(longCode)\n~~~\nOutro.\n"
        #expect(LineWrapper.wrap(input, maxLength: Self.max) == input)
    }

    @Test("Pipe-table rows are preserved")
    func testTableRowsPreserved() {
        let row =
            "| col1 | "
            + String(repeating: "verylongcolumncontentvalue ", count: 10).trimmingCharacters(in: .whitespaces)
            + " | col3 |"
        #expect(row.count > Self.max)
        let input = "| col1 | col2 | col3 |\n| --- | --- | --- |\n\(row)\n"
        #expect(LineWrapper.wrap(input, maxLength: Self.max) == input)
    }

    @Test("Reference-style link definitions are preserved")
    func testReferenceLinkDefinitionPreserved() {
        let url = "https://example.com/" + String(repeating: "a", count: 200)
        let input = "Body.\n\n[ref]: \(url) \"Title\"\n"
        #expect(LineWrapper.wrap(input, maxLength: Self.max) == input)
    }

    @Test("ATX headings are not reflowed even when long")
    func testHeadingsNotReflowed() {
        let heading = "# " + String(repeating: "word ", count: 40).trimmingCharacters(in: .whitespaces)
        #expect(heading.count > Self.max)
        let output = LineWrapper.wrap(heading + "\n", maxLength: Self.max)
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
        #expect(lines[0] == heading)
    }

    @Test("Inline HTML lines are preserved")
    func testInlineHTMLPreserved() {
        let input = "<div data-attribute=\"" + String(repeating: "v", count: 200) + "\"></div>\n"
        #expect(LineWrapper.wrap(input, maxLength: Self.max) == input)
    }

    @Test("Bullet-list continuations align under the bullet text")
    func testBulletListContinuation() {
        let body = String(repeating: "word ", count: 50).trimmingCharacters(in: .whitespaces)
        let input = "- " + body + "\n"
        let output = LineWrapper.wrap(input, maxLength: Self.max)
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count >= 2)
        #expect(lines[0].hasPrefix("- "))
        for line in lines.dropFirst() {
            #expect(line.hasPrefix("  "))
        }
        for line in lines {
            #expect(line.count <= Self.max)
        }
    }

    @Test("Ordered-list continuations match numeric prefix width")
    func testOrderedListContinuation() {
        let body = String(repeating: "word ", count: 60).trimmingCharacters(in: .whitespaces)
        let input = "1. " + body + "\n"
        let output = LineWrapper.wrap(input, maxLength: Self.max)
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count >= 2)
        #expect(lines[0].hasPrefix("1. "))
        for line in lines.dropFirst() {
            #expect(line.hasPrefix("   "))
        }
    }

    @Test("Blockquote continuations keep the leading >")
    func testBlockquoteContinuation() {
        let body = String(repeating: "word ", count: 50).trimmingCharacters(in: .whitespaces)
        let input = "> " + body + "\n"
        let output = LineWrapper.wrap(input, maxLength: Self.max)
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count >= 2)
        for line in lines {
            #expect(line.hasPrefix("> "))
            #expect(line.count <= Self.max)
        }
    }

    @Test("Single token longer than maxLength is left intact on its own line")
    func testOversizedTokenLeftIntact() {
        let huge = String(repeating: "a", count: 200)
        let input = "intro \(huge) outro\n"
        let output = LineWrapper.wrap(input, maxLength: Self.max)
        #expect(output.contains(huge))
    }

    @Test("Trailing newline is preserved")
    func testTrailingNewlinePreserved() {
        let input = "one two three\n"
        #expect(LineWrapper.wrap(input, maxLength: Self.max) == input)
    }
}
