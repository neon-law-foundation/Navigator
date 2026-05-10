// Non-@testable import — if a type, init, or property is not `public`,
// this file fails to compile and CI breaks. That's the point: this test
// exists as a compile-time guard on the surface area downstream web
// apps consume. Do NOT switch to @testable.
import NavigatorWeb
import Testing

@Suite("Public surface")
struct PublicSurfaceTests {
    @Test("NavLink has a public init and public stored properties")
    func navLinkSurface() {
        let link = NavLink(label: "About", href: "/about", icon: "info")
        #expect(link.label == "About")
        #expect(link.href == "/about")
        #expect(link.icon == "info")
    }

    @Test("FooterLink has a public init and public stored properties")
    func footerLinkSurface() {
        let link = FooterLink(label: "Privacy", href: "/privacy")
        #expect(link.label == "Privacy")
        #expect(link.href == "/privacy")
        #expect(link.icon == nil)
    }

    @Test("BlogPostSummary has a public init and public stored properties")
    func blogPostSummarySurface() {
        let summary = BlogPostSummary(
            slug: "hello",
            title: "Hello",
            excerpt: "hi",
            author: "Nick"
        )
        #expect(summary.slug == "hello")
        #expect(summary.title == "Hello")
        #expect(summary.excerpt == "hi")
        #expect(summary.author == "Nick")
    }

    @Test("BlogPost has a public init and public stored properties")
    func blogPostSurface() {
        let post = BlogPost(
            slug: "hello",
            title: "Hello",
            excerpt: "hi",
            author: "Nick",
            body: "body"
        )
        #expect(post.body == "body")
    }

    @Test("WebProject has a public init and public stored properties")
    func webProjectSurface() {
        let project = WebProject(id: "alpha", name: "Alpha", href: "/projects/alpha")
        #expect(project.id == "alpha")
        #expect(project.name == "Alpha")
        #expect(project.href == "/projects/alpha")
    }

    @Test("WebUser has a public init and public stored properties")
    func webUserSurface() {
        let user = WebUser(id: "u-1", displayName: "Nick", email: "nick@example.com")
        #expect(user.id == "u-1")
        #expect(user.displayName == "Nick")
        #expect(user.email == "nick@example.com")
    }

    @Test("All three brands are public and instantiable")
    func brandsSurface() {
        let nlf: any Brand = NLFBrand()
        let neonlaw: any Brand = NeonLawBrand()
        let sagebrush: any Brand = SagebrushBrand()
        #expect(nlf.name == "Neon Law Foundation")
        #expect(neonlaw.name == "Neon Law")
        #expect(sagebrush.name == "Sagebrush")
        // NLF primary color is the cyan-700 teal that matches the logo (#0e7490).
        #expect(nlf.primaryColor == "#0e7490")
        // Sagebrush primary color is goldenrod (#DAA520), not the old #0891b2 placeholder.
        #expect(sagebrush.primaryColor == "#DAA520")
    }

    @Test("NeonLawBrand nav exposes the estate-planning referral page")
    func neonLawBrandLinksToEstatePlanning() {
        let neonlaw = NeonLawBrand()
        #expect(neonlaw.navLinks.contains { $0.href == "/estate-planning" })
    }

    @Test("SiteHeader has a public init")
    func siteHeaderSurface() {
        _ = SiteHeader(brand: NLFBrand(), authUser: nil)
        _ = SiteHeader(
            brand: SagebrushBrand(),
            authUser: WebUser(id: "u", displayName: "N", email: "n@e.com")
        )
    }

    @Test("SiteFooter has a public init")
    func siteFooterSurface() {
        _ = SiteFooter(brand: NLFBrand(), year: 2026)
    }

    @Test("BlogPostCard has a public init")
    func blogPostCardSurface() {
        let summary = BlogPostSummary(
            slug: "s",
            title: "t",
            excerpt: "e",
            author: "a"
        )
        _ = BlogPostCard(post: summary, brand: NLFBrand())
    }

    @Test("BlogPostList has a public init")
    func blogPostListSurface() {
        _ = BlogPostList(posts: [], brand: NLFBrand())
    }

    @Test("BlogPostPage has a public init")
    func blogPostPageSurface() {
        let post = BlogPost(
            slug: "s",
            title: "t",
            excerpt: "e",
            author: "a",
            body: ""
        )
        _ = BlogPostPage(post: post, brand: NLFBrand())
    }

    @Test("BlogPagination has a public init")
    func blogPaginationSurface() {
        _ = BlogPagination(current: 1, total: 3, basePath: "/blog")
    }

    @Test("BlogIndexLayout has a public init")
    func blogIndexLayoutSurface() {
        _ = BlogIndexLayout(
            posts: [],
            current: 1,
            total: 1,
            brand: NLFBrand(),
            authUser: nil
        )
    }

    @Test("BlogPostLayout has a public init")
    func blogPostLayoutSurface() {
        let post = BlogPost(
            slug: "s",
            title: "t",
            excerpt: "e",
            author: "a",
            body: ""
        )
        _ = BlogPostLayout(post: post, brand: NLFBrand(), authUser: nil)
    }

    @Test("ProjectSidebar has a public init")
    func projectSidebarSurface() {
        _ = ProjectSidebar(
            projects: [WebProject(id: "a", name: "A", href: "/a")],
            selectedId: nil
        )
    }

    @Test("PageLayout has a public init and accepts HTML builder content")
    func pageLayoutSurface() {
        _ = PageLayout(title: "Hello", brand: NLFBrand()) {
            // Empty body is fine; this is a compile-time guard.
        }
    }
}
