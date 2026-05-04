import Foundation
import NavigatorRules
import Testing

@Suite("M005 List Indent")
struct M005ListIndentTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M005Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Flat left-aligned list passes")
    func testFlatConsistent() throws {
        let file = try makeFile(content: "- a\n- b\n- c\n")
        let rule = M005_ListIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Consistently indented nested siblings pass")
    func testNestedConsistent() throws {
        let file = try makeFile(
            content: """
                - a
                  - b
                  - c
                - d
                """
        )
        let rule = M005_ListIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Misaligned sibling at same depth flags")
    func testMisalignedSibling() throws {
        let file = try makeFile(
            content: """
                - a
                  - b
                   - c
                """
        )
        let rule = M005_ListIndent()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 3)
        #expect(violations[0].context?["expected"] == "3")
        #expect(violations[0].context?["actual"] == "4")
    }

    @Test("Left-aligned ordered list across a digit boundary passes")
    func testOrderedLeftAligned() throws {
        let content =
            (1...10).map { "\($0). item\n" }.joined()
        let file = try makeFile(content: content)
        let rule = M005_ListIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Right-aligned ordered list across a digit boundary passes")
    func testOrderedRightAligned() throws {
        let content = """
             1. a
             2. b
             3. c
             4. d
             5. e
             6. f
             7. g
             8. h
             9. i
            10. j
            """
        let file = try makeFile(content: content)
        let rule = M005_ListIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Inconsistent ordered-list indent that is neither left nor right aligned flags")
    func testInconsistentOrdered() throws {
        let file = try makeFile(
            content: """
                1. a
                 2. b
                """
        )
        let rule = M005_ListIndent()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 2)
    }

    @Test("Children of different parents do not mix in one consistency check")
    func testPerParentGrouping() throws {
        // Under parent "a", nested at indent 2. Under parent "b", nested at indent 4.
        // Although both groups use a different indent than each other, each group
        // is internally consistent, so nothing is reported.
        let file = try makeFile(
            content: """
                - a
                  - a1
                  - a2
                - b
                    - b1
                    - b2
                """
        )
        let rule = M005_ListIndent()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
