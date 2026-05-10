import Foundation
import NavigatorRules
import Testing

@testable import NavigatorCLI

@Suite("LintCommand")
struct LintCommandTests {
    private func makeTestDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LintCommand-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("Default lint flags F-rule violations on a non-notation file")
    func testDefaultRunFlagsFRules() async throws {
        let dir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // A file that would fail F-rules — no notation frontmatter, lowercase
        // filename. Default rule set must surface those violations.
        let file = dir.appendingPathComponent("readme-style.md")
        try write("# Hello\n\nWelcome to the project.\n", to: file)

        let command = LintCommand(path: file.path)
        await #expect(throws: CommandError.self) {
            try await command.run()
        }
    }

    @Test("--markdown-only suppresses F-rule violations on the same file")
    func testMarkdownOnlySuppressesFRules() async throws {
        let dir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("readme-style.md")
        try write("# Hello\n\nWelcome to the project.\n", to: file)

        let command = LintCommand(path: file.path, markdownOnly: true)
        // Should not throw — only M-rules + S101 apply.
        try await command.run()
    }

    @Test("README.md is silently skipped without --no-default-excludes")
    func testReadmeSkippedByDefault() async throws {
        let dir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // README.md is in the default exclusion list. Linting it directly
        // by path should silently succeed because the engine never inspects it.
        let readme = dir.appendingPathComponent("README.md")
        try write("# Hello\n\nWelcome.\n", to: readme)

        let command = LintCommand(path: readme.path)
        try await command.run()
    }

    @Test("--no-default-excludes lints README.md")
    func testNoDefaultExcludesLintsReadme() async throws {
        let dir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // README.md with a clearly-too-long line so we know the engine
        // actually evaluated it. With --markdown-only --no-default-excludes
        // the run must surface the S101 violation.
        let readme = dir.appendingPathComponent("README.md")
        let longLine = String(repeating: "word ", count: 40).trimmingCharacters(in: .whitespaces)
        try write("# Hello\n\n\(longLine)\n", to: readme)

        let command = LintCommand(
            path: readme.path,
            markdownOnly: true,
            noDefaultExcludes: true
        )
        await #expect(throws: CommandError.self) {
            try await command.run()
        }
    }

    @Test("--fix rewraps a long paragraph and exits cleanly")
    func testFixRewrapsParagraph() async throws {
        let dir = try makeTestDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("doc.md")
        let long = String(repeating: "alpha bravo ", count: 12) + "tail"
        try write("# Title\n\n\(long)\n", to: file)

        let command = LintCommand(
            path: file.path,
            markdownOnly: true,
            fix: true
        )
        try await command.run()

        let rewritten = try String(contentsOf: file, encoding: .utf8)
        for line in rewritten.components(separatedBy: "\n") {
            #expect(line.count <= 120)
        }
    }
}
