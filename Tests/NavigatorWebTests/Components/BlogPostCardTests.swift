import Foundation
import Testing

@testable import NavigatorWeb

@Suite("BlogPostCard")
struct BlogPostCardTests {
    private func fixturePost() -> BlogPostSummary {
        BlogPostSummary(
            slug: "hello-world",
            title: "Hello, world",
            date: Date(timeIntervalSince1970: 1_735_689_600),  // 2025-01-01T00:00:00Z
            excerpt: "A first post.",
            tags: ["intro", "meta"],
            author: "Nick Shook"
        )
    }

    @Test("renders full card with tags, link, date/author, and excerpt")
    func rendersFullCard() {
        let html = BlogPostCard(post: fixturePost(), brand: NLFBrand()).render()

        let expected = """
            <article class="rounded-lg border border-gray-200 bg-white p-6 shadow-sm hover:shadow-md transition-shadow">\
            <div class="flex flex-wrap gap-2 mb-3">\
            <span class="text-xs font-medium px-2 py-1 rounded" style="color:#0e7490;background-color:#0e749014">intro</span>\
            <span class="text-xs font-medium px-2 py-1 rounded" style="color:#0e7490;background-color:#0e749014">meta</span>\
            </div>\
            <h3 class="text-xl font-semibold mb-2">\
            <a href="/blog/hello-world" class="hover:underline" style="color:#0e7490">Hello, world</a>\
            </h3>\
            <p class="text-sm text-gray-500 mb-3">2025-01-01 · Nick Shook</p>\
            <p class="text-gray-700">A first post.</p>\
            </article>
            """

        #expect(html == expected)
    }

    @Test("swaps primary color with the brand")
    func reflectsBrandColor() {
        let nlf = BlogPostCard(post: fixturePost(), brand: NLFBrand()).render()
        let neon = BlogPostCard(post: fixturePost(), brand: NeonLawBrand()).render()

        #expect(nlf.contains("color:#0e7490"))
        #expect(neon.contains("color:#7c3aed"))
    }

    @Test("renders no tag chips when tags is empty")
    func rendersNoTagChips() {
        let post = BlogPostSummary(
            slug: "no-tags",
            title: "No tags",
            date: Date(timeIntervalSince1970: 1_735_689_600),
            excerpt: "Quiet.",
            tags: [],
            author: "Nick Shook"
        )
        let html = BlogPostCard(post: post, brand: NLFBrand()).render()

        #expect(!html.contains("<span class=\"text-xs font-medium"))
        #expect(html.contains("<div class=\"flex flex-wrap gap-2 mb-3\"></div>"))
    }
}
