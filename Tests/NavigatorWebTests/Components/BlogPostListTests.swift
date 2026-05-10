import Testing

@testable import NavigatorWeb

@Suite("BlogPostList")
struct BlogPostListTests {
    private func fixturePost(slug: String, title: String) -> BlogPostSummary {
        BlogPostSummary(
            slug: slug,
            title: title,
            excerpt: "\(title) excerpt.",
            author: "Nick Shook"
        )
    }

    @Test("renders empty state when posts is empty")
    func rendersEmptyState() {
        let html = BlogPostList(posts: [], brand: NLFBrand()).render()

        #expect(html == #"<p class="text-gray-500 italic">No posts yet.</p>"#)
    }

    @Test("renders grid of cards when posts are present")
    func rendersGridOfCards() {
        let posts = [
            fixturePost(slug: "first", title: "First"),
            fixturePost(slug: "second", title: "Second"),
        ]
        let html = BlogPostList(posts: posts, brand: NLFBrand()).render()

        #expect(html.hasPrefix(#"<div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">"#))
        #expect(html.hasSuffix("</div>"))
        #expect(html.contains(#"<a href="/blog/first""#))
        #expect(html.contains(#"<a href="/blog/second""#))
        // Two cards → two <article> opens.
        let articleOpens = html.components(separatedBy: "<article ").count - 1
        #expect(articleOpens == 2)
    }

    @Test("propagates brand color to every card")
    func propagatesBrandColor() {
        let posts = [
            fixturePost(slug: "a", title: "A"),
            fixturePost(slug: "b", title: "B"),
        ]
        let html = BlogPostList(posts: posts, brand: NeonLawBrand()).render()

        // Each card has at least one occurrence of the brand color in
        // the title link's inline style.
        let occurrences = html.components(separatedBy: "color:#7c3aed").count - 1
        #expect(occurrences >= 2)
    }

    @Test("renders posts in the order supplied (caller is responsible for sort)")
    func rendersInSuppliedOrder() {
        let posts = [
            fixturePost(slug: "alpha", title: "Alpha"),
            fixturePost(slug: "beta", title: "Beta"),
            fixturePost(slug: "gamma", title: "Gamma"),
        ]
        let html = BlogPostList(posts: posts, brand: NLFBrand()).render()

        guard
            let alpha = html.range(of: "Alpha"),
            let beta = html.range(of: "Beta"),
            let gamma = html.range(of: "Gamma")
        else {
            Issue.record("expected all three titles in the rendered list")
            return
        }
        #expect(alpha.lowerBound < beta.lowerBound)
        #expect(beta.lowerBound < gamma.lowerBound)
    }
}
