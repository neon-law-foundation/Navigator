import Foundation
import NavigatorRules
import Testing

@Suite("M030 List Marker Space")
struct M030ListMarkerSpaceTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M030Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Single-space unordered items pass")
    func testSingleSpaceUnordered() throws {
        let file = try makeFile(content: "- a\n- b\n- c\n")
        let rule = M030_ListMarkerSpace()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Single-space ordered items pass")
    func testSingleSpaceOrdered() throws {
        let file = try makeFile(content: "1. a\n2. b\n3. c\n")
        let rule = M030_ListMarkerSpace()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Two spaces after unordered marker flag")
    func testTwoSpacesUnordered() throws {
        let file = try makeFile(content: "-  a\n")
        let rule = M030_ListMarkerSpace()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 1)
        #expect(violations[0].context?["expected"] == "1")
        #expect(violations[0].context?["actual"] == "2")
    }

    @Test("Two spaces after ordered marker flag")
    func testTwoSpacesOrdered() throws {
        let file = try makeFile(content: "1.  a\n")
        let rule = M030_ListMarkerSpace()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Nested items are checked as well")
    func testNestedChecked() throws {
        let file = try makeFile(
            content: """
                - a
                  -  b
                """
        )
        let rule = M030_ListMarkerSpace()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].line == 2)
    }

    @Test("Each bad item is flagged individually")
    func testMultipleBadItems() throws {
        let file = try makeFile(
            content: """
                -  a
                -  b
                - c
                """
        )
        let rule = M030_ListMarkerSpace()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 2)
        #expect(violations[0].line == 1)
        #expect(violations[1].line == 2)
    }
}
