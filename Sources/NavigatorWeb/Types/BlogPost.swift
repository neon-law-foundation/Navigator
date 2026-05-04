import Foundation

/// A full blog post including its rendered-markdown body.
///
/// Mirrors `BlogPostSummary` field-for-field and adds `body` — the post's
/// raw CommonMark/GFM source. Components render `body` via
/// `renderMarkdown(_:)` from the M3 Markdown pipeline.
public struct BlogPost: Sendable, Equatable {
    /// URL-safe identifier; used to build the post's permalink.
    public let slug: String

    /// Display title of the post.
    public let title: String

    /// Publication date of the post.
    public let date: Date

    /// A short plain-text excerpt shown on cards and in lists.
    public let excerpt: String

    /// Tags/categories the post is filed under.
    public let tags: [String]

    /// Display name of the author.
    public let author: String

    /// The post's body in CommonMark/GFM source form.
    public let body: String

    public init(
        slug: String,
        title: String,
        date: Date,
        excerpt: String,
        tags: [String],
        author: String,
        body: String
    ) {
        self.slug = slug
        self.title = title
        self.date = date
        self.excerpt = excerpt
        self.tags = tags
        self.author = author
        self.body = body
    }
}
