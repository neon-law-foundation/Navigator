import Foundation
import NavigatorRules
import Testing

@Suite("LineScanner")
struct LineScannerTests {

    @Test("Single line with no newline produces one line")
    func testSingleLine() {
        let lines = LineScanner.scan("hello")
        #expect(lines.count == 1)
        #expect(lines[0].number == 1)
        #expect(lines[0].raw == "hello")
        #expect(lines[0].isBlank == false)
        #expect(lines[0].isInFrontmatter == false)
    }

    @Test("Multiple lines are numbered 1-indexed")
    func testMultipleLines() {
        let lines = LineScanner.scan("a\nb\nc")
        #expect(lines.map(\.number) == [1, 2, 3])
        #expect(lines.map(\.raw) == ["a", "b", "c"])
    }

    @Test("Trailing newline produces an empty final line")
    func testTrailingNewline() {
        let lines = LineScanner.scan("a\n")
        #expect(lines.count == 2)
        #expect(lines[1].raw == "")
        #expect(lines[1].isBlank)
    }

    @Test("Blank lines (whitespace-only) are flagged")
    func testBlankLines() {
        let lines = LineScanner.scan("a\n   \n\t\nb")
        #expect(lines[0].isBlank == false)
        #expect(lines[1].isBlank)
        #expect(lines[2].isBlank)
        #expect(lines[3].isBlank == false)
    }

    @Test("Trimmed strips leading and trailing whitespace")
    func testTrimmed() {
        let lines = LineScanner.scan("  hello world  ")
        #expect(lines[0].trimmed == "hello world")
    }

    @Test("Frontmatter interior lines are flagged, delimiters are not")
    func testFrontmatterRange() {
        let content = """
            ---
            title: Test
            confidential: true
            ---
            # Body
            """
        let lines = LineScanner.scan(content)
        #expect(lines[0].raw == "---")
        #expect(lines[0].isInFrontmatter == false)
        #expect(lines[1].isInFrontmatter)
        #expect(lines[2].isInFrontmatter)
        #expect(lines[3].raw == "---")
        #expect(lines[3].isInFrontmatter == false)
        #expect(lines[4].isInFrontmatter == false)
    }

    @Test("File without frontmatter never flags isInFrontmatter")
    func testNoFrontmatter() {
        let content = """
            # Heading

            Body text.
            """
        let lines = LineScanner.scan(content)
        #expect(lines.allSatisfy { $0.isInFrontmatter == false })
    }

    @Test("Unterminated frontmatter is not treated as frontmatter")
    func testUnterminatedFrontmatter() {
        let content = """
            ---
            title: Test
            body line
            """
        let lines = LineScanner.scan(content)
        #expect(lines.allSatisfy { $0.isInFrontmatter == false })
    }

    @Test("CRLF line endings are split correctly")
    func testCRLF() {
        let lines = LineScanner.scan("a\r\nb\r\nc")
        #expect(lines.map(\.raw).contains("a"))
        #expect(lines.map(\.raw).contains("b"))
        #expect(lines.map(\.raw).contains("c"))
    }
}
