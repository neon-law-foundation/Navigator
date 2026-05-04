import Foundation

/// A compact blog post representation for list and card views.
///
/// This is a temporary stub introduced in Milestone 2 step 1 of the
/// pure-Swift web stack migration (sagebrush-services/AWS#112). The
/// real shape — including body — will arrive in M3 when the Markdown
/// blog pipeline lands. Fields are intentionally minimal: the
/// information needed to render `BlogPostCard` and `BlogPostList`.
public struct BlogPostSummary: Sendable, Equatable {
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

    public init(
        slug: String,
        title: String,
        date: Date,
        excerpt: String,
        tags: [String],
        author: String
    ) {
        self.slug = slug
        self.title = title
        self.date = date
        self.excerpt = excerpt
        self.tags = tags
        self.author = author
    }
}
