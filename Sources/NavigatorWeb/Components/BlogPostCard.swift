import Elementary

/// A brand-aware card rendering a single `BlogPostSummary`.
///
/// Used standalone and as the unit rendered by `BlogPostList`. The brand's
/// primary color is injected inline via a `style` attribute so the
/// accent renders without requiring a brand-specific Tailwind build; the
/// structural classes remain pure Tailwind utilities.
public struct BlogPostCard: HTML {
    public let post: BlogPostSummary
    public let brand: any Brand

    public init(post: BlogPostSummary, brand: any Brand) {
        self.post = post
        self.brand = brand
    }

    public var body: some HTML {
        article(
            .class(
                "rounded-lg border border-gray-200 bg-white p-6 shadow-sm hover:shadow-md transition-shadow"
            )
        ) {
            h3(.class("text-xl font-semibold mb-2")) {
                a(
                    .href("/blog/\(post.slug)"),
                    .class("hover:underline"),
                    .style("color:\(brand.primaryColor)")
                ) { post.title }
            }
            if !post.author.isEmpty {
                p(.class("text-sm text-gray-500 mb-3")) { post.author }
            }
            p(.class("text-gray-700")) { post.excerpt }
        }
    }
}
