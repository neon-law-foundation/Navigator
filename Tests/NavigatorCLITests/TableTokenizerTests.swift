import Foundation
import NavigatorRules
import Testing

@Suite("Table Tokenizer")
struct TableTokenizerTests {
    @Test("Both-pipe table is recognized")
    func testBothPipeStyle() throws {
        let content = """
            | Header | Header |
            | ------ | ------ |
            | Cell   | Cell   |
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 1)
        #expect(tables[0].header.cells.count == 2)
        #expect(tables[0].body.count == 1)
        #expect(tables[0].header.hasLeadingPipe == true)
        #expect(tables[0].header.hasTrailingPipe == true)
    }

    @Test("Leading-only pipe style")
    func testLeadingOnlyStyle() throws {
        let content = """
            | Header | Header
            | ------ | ------
            | Cell   | Cell
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 1)
        #expect(tables[0].header.hasLeadingPipe == true)
        #expect(tables[0].header.hasTrailingPipe == false)
        #expect(tables[0].header.cells.count == 2)
        #expect(tables[0].body.count == 1)
    }

    @Test("Trailing-only pipe style")
    func testTrailingOnlyStyle() throws {
        let content = """
            Header | Header |
            ------ | ------ |
            Cell   | Cell   |
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 1)
        #expect(tables[0].header.hasLeadingPipe == false)
        #expect(tables[0].header.hasTrailingPipe == true)
        #expect(tables[0].header.cells.count == 2)
    }

    @Test("No-pipe-edges style")
    func testNoEdgePipes() throws {
        let content = """
            Header | Header
            ------ | ------
            Cell   | Cell
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 1)
        #expect(tables[0].header.hasLeadingPipe == false)
        #expect(tables[0].header.hasTrailingPipe == false)
        #expect(tables[0].header.cells.count == 2)
    }

    @Test("Ragged body row keeps its actual cell count")
    func testRaggedRow() throws {
        let content = """
            | A | B | C |
            | - | - | - |
            | 1 | 2 |
            | 1 | 2 | 3 | 4 |
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 1)
        #expect(tables[0].header.cells.count == 3)
        #expect(tables[0].body.count == 2)
        #expect(tables[0].body[0].cells.count == 2)
        #expect(tables[0].body[1].cells.count == 4)
    }

    @Test("Alignment markers parse correctly")
    func testAlignments() throws {
        let content = """
            | A | B | C | D |
            | :-- | --: | :-: | --- |
            | 1 | 2 | 3 | 4 |
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 1)
        #expect(tables[0].alignments == [.left, .right, .center, .none])
    }

    @Test("Paragraph without delimiter is not a table")
    func testParagraphIsNotTable() throws {
        let content = """
            Just a paragraph with | a pipe in it.
            And another line | with a pipe.
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.isEmpty)
    }

    @Test("Tables inside fenced code are skipped")
    func testFencedCodeSkipped() throws {
        let content = """
            ```
            | A | B |
            | - | - |
            | 1 | 2 |
            ```
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.isEmpty)
    }

    @Test("Two tables in a document")
    func testTwoTables() throws {
        let content = """
            | A | B |
            | - | - |
            | 1 | 2 |

            | X | Y |
            | - | - |
            | a | b |
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 2)
        #expect(tables[0].startLine == 1)
        #expect(tables[1].startLine == 5)
    }

    @Test("Pipe positions are recorded")
    func testPipePositions() throws {
        let content = """
            | A | B |
            | - | - |
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 1)
        #expect(tables[0].header.pipePositions == [0, 4, 8])
    }

    @Test("Escaped pipe is not a separator")
    func testEscapedPipe() throws {
        let content = """
            | A \\| B | C |
            | - | - |
            """
        let tables = TableTokenizer.tokenize(content)
        #expect(tables.count == 1)
        #expect(tables[0].header.cells.count == 2)
    }
}
