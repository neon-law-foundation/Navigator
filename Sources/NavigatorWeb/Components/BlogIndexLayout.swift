import Elementary

/// Full-page composition for a paged blog index — `SiteHeader`, the post
/// grid (`BlogPostList`), `BlogPagination`, and `SiteFooter`.
///
/// Layouts return an `HTMLDocument` so callers can hand them straight to
/// Vapor-Elementary's `HTMLResponse`. Delegates document chrome (doctype,
/// head, Tailwind) to `PageLayout` so every entry point emits the same
/// markup. Per-page metadata (page title) is derived from the brand and
/// current page; richer customisation will arrive when the brand-aware
/// metadata layer lands in a later milestone.
public struct BlogIndexLayout: HTMLDocument {
    public let posts: [BlogPostSummary]
    public let current: Int
    public let total: Int
    public let brand: any Brand
    public let authUser: WebUser?
    public let year: Int

    public init(
        posts: [BlogPostSummary],
        current: Int,
        total: Int,
        brand: any Brand,
        authUser: WebUser? = nil,
        year: Int = 2026
    ) {
        self.posts = posts
        self.current = current
        self.total = total
        self.brand = brand
        self.authUser = authUser
        self.year = year
    }

    public var title: String { "Blog \u{00B7} \(brand.name)" }

    public var head: some HTML {
        PageLayout<EmptyHTML>.sharedHead(brand: brand)
    }

    public var body: some HTML {
        SiteHeader(brand: brand, authUser: authUser)
        main(.class("max-w-7xl mx-auto px-4 py-8")) {
            BlogPostList(posts: posts, brand: brand)
            BlogPagination(current: current, total: total, basePath: "/blog")
        }
        SiteFooter(brand: brand, year: year)
    }
}
