import Foundation

/// Provisions the agent documentation set under a fixed target directory.
///
/// The CLI always targets `~/Work`. `targetURL` exists for test injection so
/// the real home directory is never touched during testing.
struct AgentSetupCommand: Command {
    var targetURL: URL? = nil

    func run() async throws {
        let target: URL =
            targetURL
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Work")

        try FileManager.default.createDirectory(
            at: target,
            withIntermediateDirectories: true
        )

        let resourceRoot = Bundle.module.bundleURL.appendingPathComponent("AgentDocumentation")

        let plan: [(source: URL, destination: URL)] = [
            (
                resourceRoot.appendingPathComponent("AGENTS.md"),
                target.appendingPathComponent("AGENTS.md")
            ),
            (
                resourceRoot.appendingPathComponent("CLAUDE.md"),
                target.appendingPathComponent("CLAUDE.md")
            ),
            (
                resourceRoot.appendingPathComponent(".claude/commands/review.md"),
                target.appendingPathComponent(".claude/commands/review.md")
            ),
        ]

        var created = 0
        var updated = 0
        var unchanged = 0

        for entry in plan {
            let content = try String(contentsOf: entry.source, encoding: .utf8)

            try FileManager.default.createDirectory(
                at: entry.destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let destinationPath = entry.destination.path
            let status: WriteStatus
            if FileManager.default.fileExists(atPath: destinationPath) {
                let existing = (try? String(contentsOf: entry.destination, encoding: .utf8)) ?? ""
                if existing == content {
                    status = .unchanged
                    unchanged += 1
                } else {
                    try content.write(to: entry.destination, atomically: true, encoding: .utf8)
                    status = .updated
                    updated += 1
                }
            } else {
                try content.write(to: entry.destination, atomically: true, encoding: .utf8)
                status = .created
                created += 1
            }

            print("\(status.label) \(destinationPath)")
        }

        let total = created + updated + unchanged
        print(
            "Wrote \(total) files to \(target.path) "
                + "(\(created) created, \(updated) updated, \(unchanged) unchanged)."
        )
    }

    private enum WriteStatus {
        case created
        case updated
        case unchanged

        var label: String {
            switch self {
            case .created:
                return "✓ Created  "
            case .updated:
                return "✓ Updated  "
            case .unchanged:
                return "· Unchanged"
            }
        }
    }
}
