import Foundation
import NavigatorRules
import Testing

@Suite("M035 HR Style")
struct M035HRStyleTests {
    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("M035Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("Consistent dash HRs pass")
    func testConsistentDashes() throws {
        let file = try makeFile(content: "a\n\n---\n\nb\n\n---\n")
        let rule = M035_HRStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Consistent asterisk HRs pass")
    func testConsistentAsterisks() throws {
        let file = try makeFile(content: "a\n\n***\n\nb\n\n***\n")
        let rule = M035_HRStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Mixed dash and asterisk HRs are a violation")
    func testMixedStyles() throws {
        let file = try makeFile(content: "a\n\n---\n\nb\n\n***\n")
        let rule = M035_HRStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "M035")
        #expect(violations[0].line == 7)
    }

    @Test("Differing dash counts are different styles")
    func testDashCountMismatch() throws {
        let file = try makeFile(content: "a\n\n---\n\nb\n\n----\n")
        let rule = M035_HRStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Spaced dash style is distinct from tight dash style")
    func testSpacedVsTight() throws {
        let file = try makeFile(content: "a\n\n---\n\nb\n\n- - -\n")
        let rule = M035_HRStyle()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
    }

    @Test("Non-HR dash lines are ignored")
    func testNonHRDashesIgnored() throws {
        let file = try makeFile(content: "- bullet\n- item\n")
        let rule = M035_HRStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("File with no HRs passes")
    func testNoHRs() throws {
        let file = try makeFile(content: "no hrs here\n")
        let rule = M035_HRStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("Frontmatter is ignored")
    func testFrontmatterIgnored() throws {
        let file = try makeFile(
            content: """
                ---
                title: Test
                ---
                body
                """
        )
        let rule = M035_HRStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }

    @Test("HR-shaped lines inside fenced code do not seed or violate the style")
    func testFencedCodeIgnored() throws {
        let file = try makeFile(
            content: """
                a

                ---

                ```text
                ***
                ```

                ---
                """
        )
        let rule = M035_HRStyle()
        #expect(try rule.validate(file: file).isEmpty)
    }
}
