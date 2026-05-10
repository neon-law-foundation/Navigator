import Foundation

/// A parsed blog post — front-matter plus markdown body.
///
/// Intentionally flat: everything that the index page and post page need is
/// exposed directly. The corresponding `NavigatorWeb.BlogPostSummary` is
/// derived from these fields via `summary`.
public struct BlogPost: Sendable, Equatable {
    public let slug: String
    public let title: String
    public let description: String
    public let author: String
    public let body: String

    public init(
        slug: String,
        title: String,
        description: String,
        author: String,
        body: String
    ) {
        self.slug = slug
        self.title = title
        self.description = description
        self.author = author
        self.body = body
    }
}

/// Parses the Markdown blog posts bundled as a resource under
/// `Sources/NavigatorApp/Content/Blog`.
///
/// We use a tiny, purpose-built YAML front-matter parser rather than pulling
/// in a full YAML dependency — the blog front-matter schema is fixed and
/// extremely narrow (scalar strings only).
public enum BlogLoader {
    /// Loads every `*.md` in the bundled blog content directory, parses
    /// front-matter, and returns posts sorted alphabetically by title
    /// (case-insensitive).
    public static func loadAll(bundle: Bundle? = nil) throws -> [BlogPost] {
        let chosenBundle = bundle ?? Bundle.module
        let contentURL = chosenBundle.bundleURL.appendingPathComponent(
            "Content/Blog",
            isDirectory: true
        )
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: contentURL,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "md" }
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }

        var posts: [BlogPost] = []
        for url in urls {
            let raw = try String(contentsOf: url, encoding: .utf8)
            if let post = try parse(raw: raw, fallbackSlug: url.deletingPathExtension().lastPathComponent) {
                posts.append(post)
            }
        }
        return posts.sorted(by: {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        })
    }

    /// Parses a single markdown file with YAML front-matter.
    ///
    /// Expected shape:
    /// ```
    /// ---
    /// title: "..."
    /// author: "..."
    /// description: "..."
    /// slug: "..."
    /// ---
    ///
    /// Body goes here.
    /// ```
    public static func parse(raw: String, fallbackSlug: String) throws -> BlogPost? {
        guard raw.hasPrefix("---") else { return nil }

        // Split off the front-matter block.
        let trimmed = raw.drop(while: { $0 == "-" })
        let afterFirstDashes = String(trimmed)
        // Find the closing `\n---`.
        guard let endRange = afterFirstDashes.range(of: "\n---") else { return nil }
        let frontMatter = String(afterFirstDashes[afterFirstDashes.startIndex..<endRange.lowerBound])

        var body = String(afterFirstDashes[endRange.upperBound...])
        // Skip an optional leading newline after the closing `---`.
        if body.hasPrefix("\n") {
            body.removeFirst()
        }

        let values = parseFrontMatter(frontMatter)
        let title = values["title"] ?? "Untitled"
        let slug = values["slug"] ?? fallbackSlug
        let description = values["description"] ?? ""
        let author = values["author"] ?? ""

        return BlogPost(
            slug: slug,
            title: title,
            description: description,
            author: author,
            body: body
        )
    }

    /// Minimal front-matter parser: scans line-by-line, splits on the first
    /// `:`, strips surrounding whitespace and at most one layer of matching
    /// quotes from values.
    static func parseFrontMatter(_ source: String) -> [String: String] {
        var out: [String: String] = [:]
        for line in source.split(separator: "\n", omittingEmptySubsequences: true) {
            let s = line.trimmingCharacters(in: .whitespaces)
            guard let colon = s.firstIndex(of: ":") else { continue }
            let key = s[..<colon].trimmingCharacters(in: .whitespaces)
            let value = s[s.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            out[String(key)] = unwrap(String(value))
        }
        return out
    }

    /// Removes a single outer layer of matching `"..."` or `'...'` quotes.
    static func unwrap(_ s: String) -> String {
        guard s.count >= 2 else { return s }
        let first = s.first!
        let last = s.last!
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(s.dropFirst().dropLast())
        }
        return s
    }
}
