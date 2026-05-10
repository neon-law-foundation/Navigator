import Foundation
import NavigatorRules
import Testing

@Suite("NavigatorDefaultRules")
struct NavigatorDefaultRulesTests {
    /// The canonical rule order Navigator's CLI shipped with prior to
    /// the extraction. Locked here so accidental drops or reorders in
    /// `NavigatorDefaultRules.all` are caught immediately.
    private static let canonicalRuleCodes: [String] = [
        "S101",
        "F101",
        "F102",
        "F103",
        "F104",
        "F105",
        "F106",
        "M001",
        "M003",
        "M004",
        "M005",
        "M007",
        "M009",
        "M010",
        "M011",
        "M012",
        "M018",
        "M019",
        "M020",
        "M021",
        "M022",
        "M023",
        "M024",
        "M026",
        "M027",
        "M028",
        "M029",
        "M030",
        "M031",
        "M032",
        "M034",
        "M035",
        "M037",
        "M038",
        "M039",
        "M040",
        "M042",
        "M045",
        "M046",
        "M047",
        "M048",
        "M049",
        "M050",
        "M051",
        "M052",
        "M053",
        "M054",
        "M055",
        "M056",
        "M058",
        "M059",
        "M060",
    ]

    @Test("all() returns a non-empty rule set")
    func testAllReturnsNonEmpty() {
        #expect(!NavigatorDefaultRules.all().isEmpty)
    }

    @Test("all() returns the canonical rule codes in order")
    func testCanonicalRuleCodes() {
        let codes = NavigatorDefaultRules.all().map(\.code)
        #expect(codes == Self.canonicalRuleCodes)
    }

    @Test("all() builds successfully with a custom validQuestionCodes set")
    func testHonorsCustomValidQuestionCodes() {
        let custom: Set<String> = ["custom__code__one", "custom__code__two"]
        let rules = NavigatorDefaultRules.all(validQuestionCodes: custom)
        #expect(rules.contains { $0.code == "F104" })
    }

    @Test("RuleEngine built from all() runs without throwing")
    func testEngineRunsAgainstFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NavigatorDefaultRulesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("Empty.md")
        try "# Empty\n".write(to: file, atomically: true, encoding: .utf8)

        let engine = RuleEngine(rules: NavigatorDefaultRules.all())
        _ = try engine.lint(directory: tempDir)
    }

    /// Exercises the downstream-extension pattern from the issue:
    /// a custom rule is appended to the canonical list and run through
    /// `RuleEngine` exactly as a Compass-style consumer would.
    @Test("Custom rules can be appended to all() and executed")
    func testDownstreamExtensionPattern() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownstreamExtension-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("Sample.md")
        try "# Sample\n\nbanned-token here\n"
            .write(to: file, atomically: true, encoding: .utf8)

        let rules = NavigatorDefaultRules.all() + [BannedTokenRule(token: "banned-token")]
        let engine = RuleEngine(rules: rules)
        let result = try engine.lint(file: file)

        let bannedViolations = result.fileViolations
            .flatMap(\.violations)
            .filter { $0.ruleCode == "X001" }
        #expect(bannedViolations.count == 1)
    }

    @Test("markdownOnly() drops every F-rule")
    func testMarkdownOnlyHasNoFRules() {
        let codes = NavigatorDefaultRules.markdownOnly().map(\.code)
        #expect(!codes.isEmpty)
        for code in codes {
            #expect(!code.hasPrefix("F"))
        }
    }

    @Test("markdownOnly() keeps S101 and the M-family in canonical order")
    func testMarkdownOnlyOrder() {
        let allCodes = NavigatorDefaultRules.all().map(\.code)
        let expected = allCodes.filter { !$0.hasPrefix("F") }
        let actual = NavigatorDefaultRules.markdownOnly().map(\.code)
        #expect(actual == expected)
    }

    @Test("markdownOnly() does not flag a plain README without notation frontmatter")
    func testMarkdownOnlySkipsFRuleViolations() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownOnly-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // A plain README — no frontmatter, no PascalCase filename. The full
        // rule set would fire several F-rules; markdownOnly() must not.
        let file = tempDir.appendingPathComponent("readme-style.md")
        try "# Hello\n\nWelcome.\n".write(to: file, atomically: true, encoding: .utf8)

        let engine = RuleEngine(
            rules: NavigatorDefaultRules.markdownOnly(),
            excludedFilenames: [],
            excludedDirectories: []
        )
        let result = try engine.lint(file: file)
        let codes = result.fileViolations.flatMap(\.violations).map(\.ruleCode)
        for code in codes {
            #expect(!code.hasPrefix("F"))
        }
    }
}

/// Minimal downstream rule used to verify that a custom `Rule`
/// implementation can be appended to `NavigatorDefaultRules.all()`
/// and executed by `RuleEngine` without copying any wiring.
private struct BannedTokenRule: Rule {
    let token: String

    var code: String { "X001" }
    var description: String { "Files must not contain '\(token)'" }

    func validate(file: URL) throws -> [Violation] {
        let contents = try String(contentsOf: file, encoding: .utf8)
        return contents.contains(token)
            ? [Violation(ruleCode: code, message: "contains '\(token)'")]
            : []
    }
}
