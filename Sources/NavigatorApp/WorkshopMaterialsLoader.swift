import Foundation

/// One workshop handout — the raw Markdown source plus its presentation
/// metadata.
///
/// The raw Markdown body is what participants actually paste into Claude
/// Code, so it is preserved byte-for-byte. `title` and `description` are
/// surfaced on the landing page and in the material page header. `rawURL`
/// points at the same file served unchanged by `FileMiddleware` for
/// `curl`/`wget` downloads outside the browser.
public struct WorkshopMaterial: Sendable, Equatable {
    public let slug: String
    public let title: String
    public let description: String
    public let rawMarkdown: String
    public let rawURL: String

    public init(
        slug: String,
        title: String,
        description: String,
        rawMarkdown: String,
        rawURL: String
    ) {
        self.slug = slug
        self.title = title
        self.description = description
        self.rawMarkdown = rawMarkdown
        self.rawURL = rawURL
    }
}

/// Loads the Claude Code + Twelve Zodiac Lawyers workshop materials from
/// `Public/workshops/claude-code-zodiac/` once at application startup.
///
/// The materials live in `Public/` so `FileMiddleware` can serve the raw
/// files at `/workshops/claude-code-zodiac/*.md`. This loader also reads
/// them into memory so the rendered `/workshops/genai-training/:slug`
/// pages can copy the raw source into a clipboard button and render the
/// Markdown body alongside it.
public enum WorkshopMaterialsLoader {
    /// The three materials, in the order they appear on the landing page.
    public static let manifest: [(slug: String, title: String, description: String, filename: String)] = [
        (
            slug: "readme",
            title: "Participant runbook",
            description:
                "Install, authenticate, verify, download, exercise, and debrief \u{2014} "
                + "step by step.",
            filename: "README.md"
        ),
        (
            slug: "operating-agreement",
            title: "Sample operating agreement",
            description: "The fictional Nevada LLC operating agreement every persona reviews.",
            filename: "operating-agreement.md"
        ),
        (
            slug: "personas",
            title: "Twelve persona prompts",
            description: "Copy-paste prompts for all twelve zodiac personas plus the debrief prompt.",
            filename: "personas.md"
        ),
    ]

    /// Reads every manifest entry from disk and returns the loaded
    /// `WorkshopMaterial` values in manifest order. Missing files are
    /// skipped so a partial install still boots; the landing page silently
    /// drops download cards for materials it cannot find.
    public static func loadAll(publicDirectory: String) throws -> [WorkshopMaterial] {
        let folder = URL(fileURLWithPath: publicDirectory)
            .appendingPathComponent("workshops", isDirectory: true)
            .appendingPathComponent("claude-code-zodiac", isDirectory: true)

        var materials: [WorkshopMaterial] = []
        for entry in manifest {
            let fileURL = folder.appendingPathComponent(entry.filename)
            guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            materials.append(
                WorkshopMaterial(
                    slug: entry.slug,
                    title: entry.title,
                    description: entry.description,
                    rawMarkdown: raw,
                    rawURL: "/workshops/claude-code-zodiac/\(entry.filename)"
                )
            )
        }
        return materials
    }
}
