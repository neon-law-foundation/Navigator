import Elementary

/// A brand-aware list of `BlogPostCard`s.
///
/// Renders an empty-state message when `posts` is empty rather than an empty
/// grid so that server-rendered index pages degrade gracefully when a brand
/// has no published posts yet.
public struct BlogPostList: HTML {
    public let posts: [BlogPostSummary]
    public let brand: any Brand

    public init(posts: [BlogPostSummary], brand: any Brand) {
        self.posts = posts
        self.brand = brand
    }

    public var body: some HTML {
        if posts.isEmpty {
            p(.class("text-gray-500 italic")) { "No posts yet." }
        } else {
            div(.class("grid gap-6 md:grid-cols-2 lg:grid-cols-3")) {
                for post in posts {
                    BlogPostCard(post: post, brand: brand)
                }
            }
        }
    }
}
