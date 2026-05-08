import Foundation
import Testing

@testable import NavigatorCLI

@Suite("Agent Setup Command")
struct AgentSetupCommandTests {

    private func makeTestDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "agent-setup-test-\(UUID())"
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("First run creates AGENTS.md, CLAUDE.md, and .claude/commands/review.md")
    func testFirstRunCreatesAllFiles() async throws {
        let testDir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let command = AgentSetupCommand(targetURL: testDir)
        try await command.run()

        #expect(
            FileManager.default.fileExists(atPath: testDir.appendingPathComponent("AGENTS.md").path)
        )
        #expect(
            FileManager.default.fileExists(atPath: testDir.appendingPathComponent("CLAUDE.md").path)
        )
        #expect(
            FileManager.default.fileExists(
                atPath: testDir.appendingPathComponent(".claude/commands/review.md").path
            )
        )
    }

    @Test("CLAUDE.md is the exact one-line pointer")
    func testClaudeMdIsOneLinePointer() async throws {
        let testDir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let command = AgentSetupCommand(targetURL: testDir)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(content == "Read AGENTS.md.\n")
    }

    @Test("AGENTS.md contains legal review header and IRAC")
    func testAgentsMdContainsLegalReviewAndIRAC() async throws {
        let testDir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let command = AgentSetupCommand(targetURL: testDir)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent("AGENTS.md"),
            encoding: .utf8
        )
        #expect(content.contains("# Legal Review"))
        #expect(content.contains("**Issue**"))
        #expect(content.contains("**Rule**"))
        #expect(content.contains("**Analysis**"))
        #expect(content.contains("**Conclusion**"))
        #expect(content.contains("PRIVILEGED AND CONFIDENTIAL"))
    }

    @Test("AGENTS.md describes Navigator's actual rule set")
    func testAgentsMdListsRealFRules() async throws {
        let testDir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let command = AgentSetupCommand(targetURL: testDir)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent("AGENTS.md"),
            encoding: .utf8
        )
        #expect(content.contains("F101"))
        #expect(content.contains("F102"))
        #expect(content.contains("F104"))
        #expect(content.contains("F105"))
        #expect(content.contains("F106"))
        #expect(content.contains("staff_review"))
    }

    @Test("review.md contains all 12 zodiac lawyer agents")
    func testReviewMdContainsZodiacAgents() async throws {
        let testDir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let command = AgentSetupCommand(targetURL: testDir)
        try await command.run()

        let content = try String(
            contentsOf: testDir.appendingPathComponent(".claude/commands/review.md"),
            encoding: .utf8
        )
        for sign in [
            "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
            "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
        ] {
            #expect(content.contains(sign))
        }
        #expect(content.contains("IN PARALLEL"))
    }

    @Test("Second run with no edits leaves all files unchanged")
    func testSecondRunUnchanged() async throws {
        let testDir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let command = AgentSetupCommand(targetURL: testDir)
        try await command.run()

        let agentsBefore = try Data(
            contentsOf: testDir.appendingPathComponent("AGENTS.md")
        )
        let claudeBefore = try Data(
            contentsOf: testDir.appendingPathComponent("CLAUDE.md")
        )
        let reviewBefore = try Data(
            contentsOf: testDir.appendingPathComponent(".claude/commands/review.md")
        )

        try await command.run()

        let agentsAfter = try Data(
            contentsOf: testDir.appendingPathComponent("AGENTS.md")
        )
        let claudeAfter = try Data(
            contentsOf: testDir.appendingPathComponent("CLAUDE.md")
        )
        let reviewAfter = try Data(
            contentsOf: testDir.appendingPathComponent(".claude/commands/review.md")
        )

        #expect(agentsBefore == agentsAfter)
        #expect(claudeBefore == claudeAfter)
        #expect(reviewBefore == reviewAfter)
    }

    @Test("Second run after editing AGENTS.md restores the bundled content")
    func testSecondRunRestoresEditedFile() async throws {
        let testDir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: testDir) }

        let command = AgentSetupCommand(targetURL: testDir)
        try await command.run()

        let agentsURL = testDir.appendingPathComponent("AGENTS.md")
        let original = try String(contentsOf: agentsURL, encoding: .utf8)

        try "tampered\n".write(to: agentsURL, atomically: true, encoding: .utf8)

        try await command.run()

        let restored = try String(contentsOf: agentsURL, encoding: .utf8)
        #expect(restored == original)
    }

}
