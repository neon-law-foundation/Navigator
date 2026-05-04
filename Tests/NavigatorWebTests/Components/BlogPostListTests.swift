import Foundation
import Testing

@testable import NavigatorWeb

@Suite("BlogPostList")
struct BlogPostListTests {
    private func fixturePost(slug: String, title: String) -> BlogPostSummary {
        BlogPostSummary(
            slug: slug,
            title: title,
            date: Date(timeIntervalSince1970: 1_735_689_600),
            excerpt: "\(title) excerpt.",
            tags: ["tag"],
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

        let occurrences = html.components(separatedBy: "color:#7c3aed").count - 1
        // 2 cards × (1 title link color + 1 style attr color mention per tag chip × 1 tag) = 4.
        #expect(occurrences >= 4)
    }
}
