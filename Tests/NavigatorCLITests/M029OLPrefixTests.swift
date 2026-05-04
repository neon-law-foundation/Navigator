import Foundation
import NavigatorRules
import Testing

@Suite("M029 OL Prefix")
struct M029OLPrefixTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M029Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Sequential 1,2,3 ordered list passes")
    func testSequential() throws {
        let file = try makeFile(content: "1. a\n2. b\n3. c\n")
        let rule = M029_OLPrefix()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("All-1s ordered list passes")
    func testAllOnes() throws {
        let file = try makeFile(content: "1. a\n1. b\n1. c\n")
        let rule = M029_OLPrefix()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Out-of-sequence values flag")
    func testOutOfSequence() throws {
        let file = try makeFile(content: "1. a\n3. b\n4. c\n")
        let rule = M029_OLPrefix()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
        #expect(violations[0].line == 2)
        #expect(violations[0].context?["expected"] == "2")
        #expect(violations[0].context?["actual"] == "3")
        #expect(violations[1].line == 3)
        #expect(violations[1].context?["expected"] == "3")
    }

    @Test("List starting with non-1 flags the first item")
    func testStartsNotAtOne() throws {
        let file = try makeFile(content: "3. a\n4. b\n5. c\n")
        let rule = M029_OLPrefix()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 1)
        #expect(violations[0].context?["expected"] == "1")
    }

    @Test("Unordered item at same depth breaks the ordered run")
    func testUnorderedBreaksRun() throws {
        let file = try makeFile(
            content: """
                1. a
                2. b
                - c
                1. d
                2. e
                """
        )
        let rule = M029_OLPrefix()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Nested ordered lists each have their own sequence")
    func testNestedSequences() throws {
        let file = try makeFile(
            content: """
                1. outer1
                   1. inner1
                   2. inner2
                2. outer2
                   1. other1
                   2. other2
                """
        )
        let rule = M029_OLPrefix()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Nested ordered list with bad numbering flags only that run")
    func testNestedBadOnly() throws {
        let file = try makeFile(
            content: """
                1. outer1
                   1. inner1
                   3. inner2
                2. outer2
                """
        )
        let rule = M029_OLPrefix()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 3)
    }

    @Test("Unordered list is not checked")
    func testUnorderedIgnored() throws {
        let file = try makeFile(content: "- a\n- b\n- c\n")
        let rule = M029_OLPrefix()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
