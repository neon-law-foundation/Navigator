import Testing

@testable import NavigatorWeb

@Suite("BlogIndexLayout")
struct BlogIndexLayoutTests {
    private func fixturePost(slug: String, title: String) -> BlogPostSummary {
        BlogPostSummary(
            slug: slug,
            title: title,
            excerpt: "\(title) excerpt.",
            author: "Nick Shook"
        )
    }

    @Test("composes header, post grid, pagination, and footer in order")
    func composesAllSections() {
        let posts = [
            fixturePost(slug: "first", title: "First"),
            fixturePost(slug: "second", title: "Second"),
        ]
        let html = BlogIndexLayout(
            posts: posts,
            current: 1,
            total: 2,
            brand: NLFBrand(),
            authUser: nil
        ).render()

        guard
            let headerIndex = html.range(of: "<header"),
            let articleIndex = html.range(of: "<article"),
            let paginationIndex = html.range(of: "<nav class=\"flex items-center justify-between"),
            let footerIndex = html.range(of: "<footer")
        else {
            Issue.record("expected header/article/pagination/footer markers in output")
            return
        }
        #expect(headerIndex.lowerBound < articleIndex.lowerBound)
        #expect(articleIndex.lowerBound < paginationIndex.lowerBound)
        #expect(paginationIndex.lowerBound < footerIndex.lowerBound)
    }

    @Test("shows authenticated display name when authUser is provided")
    func showsAuthenticatedDisplayName() {
        let user = WebUser(id: "u-1", displayName: "Grace Hopper", email: "grace@example.com")
        let html = BlogIndexLayout(
            posts: [],
            current: 1,
            total: 1,
            brand: NLFBrand(),
            authUser: user
        ).render()

        #expect(html.contains("Grace Hopper"))
        #expect(html.contains(#"href="/logout""#))
        // Empty-state still rendered by inner BlogPostList.
        #expect(html.contains("No posts yet."))
    }

    @Test("preserves caller-supplied title order in the rendered grid")
    func preservesAlphabeticalOrder() {
        let posts = [
            fixturePost(slug: "alpha", title: "Alpha"),
            fixturePost(slug: "beta", title: "Beta"),
            fixturePost(slug: "gamma", title: "Gamma"),
        ]
        let html = BlogIndexLayout(
            posts: posts,
            current: 1,
            total: 1,
            brand: NLFBrand(),
            authUser: nil
        ).render()

        guard
            let alpha = html.range(of: "Alpha"),
            let beta = html.range(of: "Beta"),
            let gamma = html.range(of: "Gamma")
        else {
            Issue.record("expected all three titles in the rendered layout")
            return
        }
        #expect(alpha.lowerBound < beta.lowerBound)
        #expect(beta.lowerBound < gamma.lowerBound)
    }
}
