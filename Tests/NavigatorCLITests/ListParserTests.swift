import Foundation
import NavigatorRules
import Testing

@Suite("ListParser")
struct ListParserTests {

    @Test("Empty content yields no lists")
    func testEmpty() {
        #expect(ListParser.parseLists(in: "").isEmpty)
    }

    @Test("Top-level unordered items are depth 0")
    func testTopLevelUnordered() {
        let parsed = ListParser.parseLists(in: "- a\n- b\n- c\n")
        #expect(parsed.count == 1)
        #expect(parsed[0].items.count == 3)
        for item in parsed[0].items {
            #expect(item.depth == 0)
            #expect(item.parentIndex == nil)
            #expect(item.markerColumn == 1)
            #expect(item.markerDelim == "-")
            #expect(item.ordered == false)
        }
    }

    @Test("Ordered items expose their numeric value")
    func testOrderedValue() {
        let parsed = ListParser.parseLists(in: "1. a\n2. b\n3. c\n")
        #expect(parsed.count == 1)
        let values = parsed[0].items.map(\.orderedValue)
        #expect(values == [1, 2, 3])
        #expect(parsed[0].items.allSatisfy { $0.ordered })
        #expect(parsed[0].items.allSatisfy { $0.markerDelim == "." })
    }

    @Test("Multi-digit ordered items have correct marker width")
    func testMultiDigitOrdered() {
        let content = """
            1. a
            2. b
            10. x
            """
        let parsed = ListParser.parseLists(in: content)
        let widths = parsed[0].items.map(\.markerWidth)
        #expect(widths == [2, 2, 3])
        let contentCols = parsed[0].items.map(\.contentColumn)
        #expect(contentCols == [4, 4, 5])
    }

    @Test("Nested list items gain depth via marker column vs parent content column")
    func testNestedDepth() {
        let content = """
            - a
              - b
                - c
            """
        let parsed = ListParser.parseLists(in: content)
        #expect(parsed.count == 1)
        let depths = parsed[0].items.map(\.depth)
        #expect(depths == [0, 1, 2])
        #expect(parsed[0].items[1].parentIndex == 0)
        #expect(parsed[0].items[2].parentIndex == 1)
    }

    @Test("Four-level nesting tracks depth correctly")
    func testFourLevels() {
        let content = """
            - l0
              - l1
                - l2
                  - l3
                - l2b
              - l1b
            - l0b
            """
        let parsed = ListParser.parseLists(in: content)
        let depths = parsed[0].items.map(\.depth)
        #expect(depths == [0, 1, 2, 3, 2, 1, 0])
    }

    @Test("Insufficient indent becomes a sibling, not a child")
    func testInsufficientIndentSibling() {
        // " - b" is one space of indent; "- a" has content column 3, so "b" at marker column 2
        // is not a child of "a".
        let content = "- a\n - b\n"
        let parsed = ListParser.parseLists(in: content)
        let depths = parsed[0].items.map(\.depth)
        #expect(depths == [0, 0])
    }

    @Test("Mixed markers across items preserve each marker character")
    func testMixedMarkers() {
        let content = """
            - a
            * b
            + c
            """
        let parsed = ListParser.parseLists(in: content)
        let markers = parsed[0].items.map(\.markerDelim)
        #expect(markers == ["-", "*", "+"])
    }

    @Test("Spaces after marker are counted precisely")
    func testSpacesAfterMarker() {
        let content = """
            -  two spaces
            -   three spaces
            - one space
            """
        let parsed = ListParser.parseLists(in: content)
        let spaces = parsed[0].items.map(\.spacesAfterMarker)
        #expect(spaces == [2, 3, 1])
    }

    @Test("Continuation lines are not treated as items")
    func testContinuationSkipped() {
        let content = """
            - item 1
              continuation
            - item 2
            """
        let parsed = ListParser.parseLists(in: content)
        #expect(parsed[0].items.count == 2)
        #expect(parsed[0].items.map(\.line) == [1, 3])
    }

    @Test("Multiple list blocks separated by blanks become separate ParsedLists")
    func testMultipleBlocks() {
        let content = """
            - a
            - b

            - c
            - d
            """
        let parsed = ListParser.parseLists(in: content)
        #expect(parsed.count == 2)
        #expect(parsed[0].items.count == 2)
        #expect(parsed[1].items.count == 2)
    }
}
