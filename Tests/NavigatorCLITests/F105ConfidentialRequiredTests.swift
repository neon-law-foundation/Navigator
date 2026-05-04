import Foundation
import NavigatorRules
import Testing

@Suite("F105 Confidential Required")
struct F105ConfidentialRequiredTests {
    private func makeFile(named name: String = "TestFile.md", content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("F105Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent(name)
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test("confidential: true passes")
    func testConfidentialTruePasses() throws {
        let content = """
            ---
            title: Test
            confidential: true
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F105_ConfidentialRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }

    @Test("confidential: false passes")
    func testConfidentialFalsePasses() throws {
        let content = """
            ---
            title: Test
            confidential: false
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F105_ConfidentialRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }

    @Test("Missing confidential key produces violation")
    func testMissingConfidentialKey() throws {
        let content = """
            ---
            title: Test
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F105_ConfidentialRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F105")
        #expect(violations[0].message == "Frontmatter must contain a 'confidential' field")
    }

    @Test("confidential: yes produces violation")
    func testConfidentialYesProducesViolation() throws {
        let content = """
            ---
            title: Test
            confidential: yes
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F105_ConfidentialRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F105")
        #expect(violations[0].message == "Frontmatter 'confidential' field must be 'true' or 'false'")
    }

    @Test("confidential: 1 produces violation")
    func testConfidentialOneProducesViolation() throws {
        let content = """
            ---
            title: Test
            confidential: 1
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F105_ConfidentialRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F105")
    }

    @Test("No frontmatter produces violation")
    func testNoFrontmatterProducesViolation() throws {
        let content = """
            # Just a plain markdown file

            No frontmatter here.
            """
        let file = try makeFile(content: content)
        let rule = F105_ConfidentialRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F105")
        #expect(violations[0].message == "Missing frontmatter with confidential field")
    }

    @Test("Empty confidential value produces violation")
    func testEmptyConfidentialValueProducesViolation() throws {
        let content = """
            ---
            title: Test
            confidential:
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F105_ConfidentialRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F105")
    }

    @Test("README.md is skipped entirely")
    func testReadmeMdSkipped() throws {
        let content = """
            # README

            No frontmatter, no confidential field.
            """
        let file = try makeFile(named: "README.md", content: content)
        let rule = F105_ConfidentialRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }
}
