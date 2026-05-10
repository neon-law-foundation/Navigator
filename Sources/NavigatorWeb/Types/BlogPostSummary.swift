/// A compact blog post representation for list and card views.
///
/// Fields are intentionally minimal: the information needed to render
/// `BlogPostCard` and `BlogPostList`.
public struct BlogPostSummary: Sendable, Equatable {
    /// URL-safe identifier; used to build the post's permalink.
    public let slug: String

    /// Display title of the post.
    public let title: String

    /// A short plain-text excerpt shown on cards and in lists.
    public let excerpt: String

    /// Display name of the author.
    public let author: String

    public init(
        slug: String,
        title: String,
        excerpt: String,
        author: String
    ) {
        self.slug = slug
        self.title = title
        self.excerpt = excerpt
        self.author = author
    }
}
