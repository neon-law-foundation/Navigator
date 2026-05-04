import Foundation
import NavigatorRules
import Testing

@Suite("BlockTokenizer")
struct BlockTokenizerTests {

    @Test("Empty string tokenizes to no blocks")
    func testEmpty() {
        #expect(BlockTokenizer.tokenize("").isEmpty)
    }

    @Test("Single paragraph")
    func testParagraph() {
        let blocks = BlockTokenizer.tokenize("hello world\n")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .paragraph)
        #expect(blocks[0].startLine == 1)
        #expect(blocks[0].endLine == 1)
    }

    @Test("ATX heading is its own block")
    func testATXHeading() {
        let blocks = BlockTokenizer.tokenize("# Title\n\nbody\n")
        #expect(blocks.count == 3)
        if case .heading(let level, let style, let text) = blocks[0].kind {
            #expect(level == 1)
            #expect(style == .atx)
            #expect(text == "Title")
        } else {
            Issue.record("Expected heading")
        }
        #expect(blocks[1].kind == .blank)
        #expect(blocks[2].kind == .paragraph)
    }

    @Test("Closed ATX heading detected")
    func testATXClosedHeading() {
        let blocks = BlockTokenizer.tokenize("## Title ##\n")
        guard case .heading(let level, let style, let text) = blocks[0].kind else {
            Issue.record("Expected heading")
            return
        }
        #expect(level == 2)
        #expect(style == .atxClosed)
        #expect(text == "Title")
    }

    @Test("Setext h1")
    func testSetextH1() {
        let blocks = BlockTokenizer.tokenize("Title\n=====\n")
        #expect(blocks.count == 1)
        if case .heading(let level, let style, let text) = blocks[0].kind {
            #expect(level == 1)
            #expect(style == .setext)
            #expect(text == "Title")
        } else {
            Issue.record("Expected setext heading")
        }
        #expect(blocks[0].startLine == 1)
        #expect(blocks[0].endLine == 2)
    }

    @Test("Setext h2")
    func testSetextH2() {
        let blocks = BlockTokenizer.tokenize("Title\n---\n")
        if case .heading(let level, _, _) = blocks[0].kind {
            #expect(level == 2)
        } else {
            Issue.record("Expected setext heading")
        }
    }

    @Test("Horizontal rule")
    func testHR() {
        let blocks = BlockTokenizer.tokenize("a\n\n---\n\nb\n")
        #expect(blocks[2].kind == .hr)
    }

    @Test("Fenced code block with backticks and language")
    func testFencedCodeBackticks() {
        let blocks = BlockTokenizer.tokenize("```swift\nlet x = 1\n```\n")
        #expect(blocks.count == 1)
        if case .fencedCode(let marker, let info) = blocks[0].kind {
            #expect(marker == .backtick)
            #expect(info == "swift")
        } else {
            Issue.record("Expected fenced code block")
        }
        #expect(blocks[0].startLine == 1)
        #expect(blocks[0].endLine == 3)
    }

    @Test("Fenced code block with tildes")
    func testFencedCodeTildes() {
        let blocks = BlockTokenizer.tokenize("~~~\ncode\n~~~\n")
        if case .fencedCode(let marker, _) = blocks[0].kind {
            #expect(marker == .tilde)
        } else {
            Issue.record("Expected tilde fence")
        }
    }

    @Test("Indented code block")
    func testIndentedCode() {
        let blocks = BlockTokenizer.tokenize("text\n\n    code\n    more\n\ntext\n")
        #expect(blocks[0].kind == .paragraph)
        #expect(blocks[1].kind == .blank)
        #expect(blocks[2].kind == .indentedCode)
        #expect(blocks[2].startLine == 3)
        #expect(blocks[2].endLine == 4)
        #expect(blocks[3].kind == .blank)
        #expect(blocks[4].kind == .paragraph)
    }

    @Test("Indented after paragraph is paragraph continuation")
    func testIndentedContinuationNotCode() {
        let blocks = BlockTokenizer.tokenize("paragraph\n    indented continuation\n")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .paragraph)
    }

    @Test("Blockquote span")
    func testBlockquote() {
        let blocks = BlockTokenizer.tokenize("> quote line 1\n> quote line 2\n")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .blockquote)
        #expect(blocks[0].endLine == 2)
    }

    @Test("Unordered list")
    func testUnorderedList() {
        let blocks = BlockTokenizer.tokenize("- a\n- b\n- c\n")
        #expect(blocks.count == 1)
        if case .list(let marker, let ordered) = blocks[0].kind {
            #expect(marker == "-")
            #expect(ordered == false)
        } else {
            Issue.record("Expected list")
        }
    }

    @Test("Ordered list")
    func testOrderedList() {
        let blocks = BlockTokenizer.tokenize("1. a\n2. b\n")
        if case .list(_, let ordered) = blocks[0].kind {
            #expect(ordered)
        } else {
            Issue.record("Expected ordered list")
        }
    }

    @Test("Blank line block")
    func testBlankBlock() {
        let blocks = BlockTokenizer.tokenize("a\n\nb\n")
        #expect(blocks[1].kind == .blank)
        #expect(blocks[1].startLine == 2)
        #expect(blocks[1].endLine == 2)
    }

    @Test("Consecutive blanks collapse to one block")
    func testCollapseBlanks() {
        let blocks = BlockTokenizer.tokenize("a\n\n\n\nb\n")
        #expect(blocks[1].kind == .blank)
        #expect(blocks[1].startLine == 2)
        #expect(blocks[1].endLine == 4)
    }

    @Test("YAML frontmatter detected")
    func testFrontmatter() {
        let content = """
            ---
            title: Test
            ---
            # Body
            """
        let blocks = BlockTokenizer.tokenize(content)
        #expect(blocks[0].kind == .frontmatter)
        #expect(blocks[0].startLine == 1)
        #expect(blocks[0].endLine == 3)
    }

    @Test("Unterminated fence consumes to EOF")
    func testUnterminatedFence() {
        let blocks = BlockTokenizer.tokenize("```\ncode\n")
        #expect(blocks.count == 1)
        if case .fencedCode = blocks[0].kind {
            // ok
        } else {
            Issue.record("Expected unterminated fence to still be a fencedCode block")
        }
    }

    @Test("Fence inside paragraph triggers new block on reopen")
    func testNestedFenceAfterParagraph() {
        let content = """
            paragraph line

            ```ts
            code
            ```

            after
            """
        let blocks = BlockTokenizer.tokenize(content)
        #expect(blocks.contains { if case .fencedCode = $0.kind { true } else { false } })
    }

    @Test("Every line is in exactly one block")
    func testCoverage() {
        let content = """
            ---
            title: Test
            ---

            # H1

            para line 1
            para line 2

            - list a
            - list b

            > quote

                code

            ```swift
            fenced
            ```

            ---

            final
            """
        let blocks = BlockTokenizer.tokenize(content)
        let totalLines = content.components(separatedBy: .newlines).count
        // Confirm coverage of every line and non-overlapping blocks.
        var covered: Set<Int> = []
        for block in blocks {
            for line in block.startLine...block.endLine {
                #expect(!covered.contains(line), "Line \(line) covered twice")
                covered.insert(line)
            }
        }
        #expect(covered.count >= totalLines - 1)  // trailing empty from \n may be dropped
    }
}
