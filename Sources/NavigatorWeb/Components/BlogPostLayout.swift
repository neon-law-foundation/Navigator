import Elementary

/// Full-page composition for a single blog post — `SiteHeader`,
/// `BlogPostPage`, `SiteFooter`.
///
/// Returns an `HTMLDocument` so callers can hand it straight to
/// Vapor-Elementary's `HTMLResponse`. The page title is derived from the
/// post; richer per-page metadata will arrive in a later milestone.
public struct BlogPostLayout: HTMLDocument {
    public let post: BlogPost
    public let brand: any Brand
    public let authUser: WebUser?
    public let year: Int

    public init(
        post: BlogPost,
        brand: any Brand,
        authUser: WebUser? = nil,
        year: Int = 2026
    ) {
        self.post = post
        self.brand = brand
        self.authUser = authUser
        self.year = year
    }

    public var title: String { "\(post.title) \u{00B7} \(brand.name)" }

    public var head: some HTML {
        PageLayout<EmptyHTML>.sharedHead(brand: brand)
    }

    public var body: some HTML {
        SiteHeader(brand: brand, authUser: authUser)
        main {
            BlogPostPage(post: post, brand: brand)
        }
        SiteFooter(brand: brand, year: year)
    }
}
