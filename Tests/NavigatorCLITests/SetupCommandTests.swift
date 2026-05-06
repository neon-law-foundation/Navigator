import Foundation
import Testing

@testable import NavigatorCLI

@Suite("Setup Command")
struct SetupCommandTests {

    private func makeTestDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "agent-setup-test-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Default target resolves to ~/Work")
    func testDefaultTargetIsWorkUnderHome() {
        let command = SetupCommand()
        let expected = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Work")
            .standardizedFileURL
        #expect(command.targetDirectory.standardizedFileURL == expected)
    }

    @Test("First run creates AGENTS.md, CLAUDE.md, and .claude/commands/review.md")
    func testFirstRunCreatesAllFiles() async throws {
        let testDir = try makeTestDir()
        defer { cleanup(testDir) }

        let target = testDir.appendingPathComponent("Work")
        let command = SetupCommand(targetDirectory: target)
        try await command.run()

        #expect(
            FileManager.default.fileExists(
                atPath: target.appendingPathComponent("AGENTS.md").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: target.appendingPathComponent("CLAUDE.md").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: target.appendingPathComponent(".claude/commands/review.md").path
            )
        )
    }

    @Test("AGENTS.md contains the legal-review guidance")
    func testAgentsMdContainsLegalReviewGuidance() async throws {
        let testDir = try makeTestDir()
        defer { cleanup(testDir) }

        let target = testDir.appendingPathComponent("Work")
        try await SetupCommand(targetDirectory: target).run()

        let content = try String(
            contentsOf: target.appendingPathComponent("AGENTS.md"),
            encoding: .utf8
        )
        #expect(content.contains("# Legal Review"))
        #expect(content.contains("**Issue**"))
        #expect(content.contains("**Rule**"))
        #expect(content.contains("**Analysis**"))
        #expect(content.contains("**Conclusion**"))
        #expect(content.contains("PRIVILEGED AND CONFIDENTIAL"))
        #expect(content.contains("Navigator Glossary"))
        #expect(content.contains("**Template**"))
        #expect(content.contains("**Notation**"))
        #expect(content.contains("**NotationState**"))
        #expect(content.contains("**Jurisdiction**"))
        #expect(content.contains("**PersonEntityRole**"))
        #expect(content.contains("/review"))
    }

    @Test("CLAUDE.md is exactly the one-line pointer")
    func testClaudeMdIsOneLinePointer() async throws {
        let testDir = try makeTestDir()
        defer { cleanup(testDir) }

        let target = testDir.appendingPathComponent("Work")
        try await SetupCommand(targetDirectory: target).run()

        let content = try String(
            contentsOf: target.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(content == "Read AGENTS.md.\n")
    }

    @Test("review.md contains all 12 zodiac lawyer agents and parallel directive")
    func testReviewMdContainsZodiacAgents() async throws {
        let testDir = try makeTestDir()
        defer { cleanup(testDir) }

        let target = testDir.appendingPathComponent("Work")
        try await SetupCommand(targetDirectory: target).run()

        let content = try String(
            contentsOf: target.appendingPathComponent(".claude/commands/review.md"),
            encoding: .utf8
        )
        for sign in [
            "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
            "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
        ] {
            #expect(content.contains(sign), "review.md missing zodiac sign: \(sign)")
        }
        #expect(content.contains("IN PARALLEL"))
    }

    @Test("Bundled resources load successfully via Bundle.module")
    func testBundledResourcesAvailable() throws {
        let agents = Bundle.module.url(
            forResource: "AGENTS",
            withExtension: "md",
            subdirectory: "AgentDocumentation"
        )
        let claude = Bundle.module.url(
            forResource: "CLAUDE",
            withExtension: "md",
            subdirectory: "AgentDocumentation"
        )
        let review = Bundle.module.url(
            forResource: "review",
            withExtension: "md",
            subdirectory: "AgentDocumentation/.claude/commands"
        )
        #expect(agents != nil, "AGENTS.md not bundled")
        #expect(claude != nil, "CLAUDE.md not bundled")
        #expect(review != nil, "review.md not bundled")
    }

    @Test("Second run with no edits leaves all files unchanged")
    func testSecondRunUnchanged() async throws {
        let testDir = try makeTestDir()
        defer { cleanup(testDir) }

        let target = testDir.appendingPathComponent("Work")
        let command = SetupCommand(targetDirectory: target)

        try await command.run()

        let agentsURL = target.appendingPathComponent("AGENTS.md")
        let claudeURL = target.appendingPathComponent("CLAUDE.md")
        let reviewURL = target.appendingPathComponent(".claude/commands/review.md")

        let agentsBefore = try Data(contentsOf: agentsURL)
        let claudeBefore = try Data(contentsOf: claudeURL)
        let reviewBefore = try Data(contentsOf: reviewURL)

        try await command.run()

        #expect(try Data(contentsOf: agentsURL) == agentsBefore)
        #expect(try Data(contentsOf: claudeURL) == claudeBefore)
        #expect(try Data(contentsOf: reviewURL) == reviewBefore)
    }

    @Test("Modifying AGENTS.md between runs restores the bundled content")
    func testModifiedFileGetsRestored() async throws {
        let testDir = try makeTestDir()
        defer { cleanup(testDir) }

        let target = testDir.appendingPathComponent("Work")
        let command = SetupCommand(targetDirectory: target)
        try await command.run()

        let agentsURL = target.appendingPathComponent("AGENTS.md")
        try "tampered".write(to: agentsURL, atomically: true, encoding: .utf8)

        try await command.run()

        let restored = try String(contentsOf: agentsURL, encoding: .utf8)
        #expect(restored.contains("# Legal Review"))
        #expect(!restored.contains("tampered"))
    }

    @Test("Custom target directory is created if it does not exist")
    func testTargetDirectoryCreatedIfMissing() async throws {
        let testDir = try makeTestDir()
        defer { cleanup(testDir) }

        let target = testDir.appendingPathComponent("Work")
        #expect(!FileManager.default.fileExists(atPath: target.path))

        try await SetupCommand(targetDirectory: target).run()

        let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
        #expect(attributes[.type] as? FileAttributeType == .typeDirectory)
    }
}
