import Foundation
import Testing

@testable import NavigatorCLI

@Suite("Claude Setup Command")
struct ClaudeSetupCommandTests {

    private func makeTestDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "claude-setup-test-\(UUID())"
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Creates CLAUDE.md in the output directory")
    func testCreatesCLAUDEMd() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let claudeMdURL = testDir.appendingPathComponent("CLAUDE.md")
        #expect(FileManager.default.fileExists(atPath: claudeMdURL.path))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("CLAUDE.md contains legal review header")
    func testContainsLegalReviewHeader() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(content.contains("# Legal Review"))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("CLAUDE.md contains IRAC methodology")
    func testContainsIRAC() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(content.contains("**Issue**"))
        #expect(content.contains("**Rule**"))
        #expect(content.contains("**Analysis**"))
        #expect(content.contains("**Conclusion**"))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("CLAUDE.md contains privileged and confidential notice")
    func testContainsPrivilegedNotice() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(content.contains("PRIVILEGED AND CONFIDENTIAL"))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("CLAUDE.md contains Navigator glossary terms")
    func testContainsGlossary() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(content.contains("Navigator Glossary"))
        #expect(content.contains("**Template**"))
        #expect(content.contains("**Notation**"))
        #expect(content.contains("**NotationState**"))
        #expect(content.contains("**Jurisdiction**"))
        #expect(content.contains("**PersonEntityRole**"))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("CLAUDE.md references the /review skill")
    func testReferencesReviewSkill() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(content.contains("/review"))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("Creates .claude/commands/review.md")
    func testCreatesReviewMd() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let reviewURL = testDir.appendingPathComponent(".claude/commands/review.md")
        #expect(FileManager.default.fileExists(atPath: reviewURL.path))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("review.md contains all 12 zodiac lawyer agents")
    func testReviewMdContainsZodiacAgents() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent(".claude/commands/review.md"),
            encoding: .utf8
        )
        #expect(content.contains("Aries"))
        #expect(content.contains("Taurus"))
        #expect(content.contains("Gemini"))
        #expect(content.contains("Cancer"))
        #expect(content.contains("Leo"))
        #expect(content.contains("Virgo"))
        #expect(content.contains("Libra"))
        #expect(content.contains("Scorpio"))
        #expect(content.contains("Sagittarius"))
        #expect(content.contains("Capricorn"))
        #expect(content.contains("Aquarius"))
        #expect(content.contains("Pisces"))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("review.md instructs parallel agent execution")
    func testReviewMdInstructsParallelExecution() async throws {
        let testDir = try makeTestDir()

        let command = ClaudeSetupCommand(outputDirectory: testDir.path)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent(".claude/commands/review.md"),
            encoding: .utf8
        )
        #expect(content.contains("IN PARALLEL"))

        try? FileManager.default.removeItem(at: testDir)
    }
}
