import Foundation

struct SetupCommand: Command {
    /// Target directory under which `AGENTS.md`, `CLAUDE.md`, and `.claude/commands/review.md`
    /// are created. Defaults to `~/Work/`. Tests inject a temporary directory.
    var targetDirectory: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Work")

    func run() async throws {
        try FileManager.default.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )

        let agentsContent = try Self.loadBundled(name: "AGENTS", ext: "md")
        let claudeContent = try Self.loadBundled(name: "CLAUDE", ext: "md")
        let reviewContent = try Self.loadBundled(
            name: "review",
            ext: "md",
            subdirectory: ".claude/commands"
        )

        let plan: [(URL, String)] = [
            (targetDirectory.appendingPathComponent("AGENTS.md"), agentsContent),
            (targetDirectory.appendingPathComponent("CLAUDE.md"), claudeContent),
            (
                targetDirectory.appendingPathComponent(".claude/commands/review.md"),
                reviewContent
            ),
        ]

        var created = 0
        var updated = 0
        var unchanged = 0

        for (url, content) in plan {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let status = try Self.classify(target: url, newContent: content)
            try content.write(to: url, atomically: true, encoding: .utf8)

            switch status {
            case .created:
                created += 1
                print("✓ Created   \(url.path)")
            case .updated:
                updated += 1
                print("✓ Updated   \(url.path)")
            case .unchanged:
                unchanged += 1
                print("· Unchanged \(url.path)")
            }
        }

        print(
            """
            Wrote \(plan.count) files to \(targetDirectory.path) \
            (\(created) created, \(updated) updated, \(unchanged) unchanged).
            """
        )
    }

    private enum WriteStatus { case created, updated, unchanged }

    private static func classify(target: URL, newContent: String) throws -> WriteStatus {
        guard FileManager.default.fileExists(atPath: target.path) else {
            return .created
        }
        let existing = try String(contentsOf: target, encoding: .utf8)
        return existing == newContent ? .unchanged : .updated
    }

    private static func loadBundled(
        name: String,
        ext: String,
        subdirectory: String? = nil
    ) throws -> String {
        let resourceSubdir =
            subdirectory.map { "AgentDocumentation/\($0)" } ?? "AgentDocumentation"
        guard
            let url = Bundle.module.url(
                forResource: name,
                withExtension: ext,
                subdirectory: resourceSubdir
            )
        else {
            throw SetupError.bundledResourceMissing(
                "\(resourceSubdir)/\(name).\(ext)"
            )
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

enum SetupError: Error, LocalizedError {
    case bundledResourceMissing(String)

    var errorDescription: String? {
        switch self {
        case .bundledResourceMissing(let path):
            return "Bundled resource not found: \(path)"
        }
    }
}
