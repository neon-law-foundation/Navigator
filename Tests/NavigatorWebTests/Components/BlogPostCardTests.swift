import Testing

@testable import NavigatorWeb

@Suite("BlogPostCard")
struct BlogPostCardTests {
    private func fixturePost(author: String = "Nick Shook") -> BlogPostSummary {
        BlogPostSummary(
            slug: "hello-world",
            title: "Hello, world",
            excerpt: "A first post.",
            author: author
        )
    }

    @Test("renders title link, author line, and excerpt")
    func rendersFullCard() {
        let html = BlogPostCard(post: fixturePost(), brand: NLFBrand()).render()

        let expected = """
            <article class="rounded-lg border border-gray-200 bg-white p-6 shadow-sm hover:shadow-md transition-shadow">\
            <h3 class="text-xl font-semibold mb-2">\
            <a href="/blog/hello-world" class="hover:underline" style="color:#0e7490">Hello, world</a>\
            </h3>\
            <p class="text-sm text-gray-500 mb-3">Nick Shook</p>\
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

    @Test("omits author line when author is empty")
    func omitsEmptyAuthor() {
        let html = BlogPostCard(post: fixturePost(author: ""), brand: NLFBrand()).render()

        #expect(!html.contains("text-sm text-gray-500"))
        #expect(html.contains("A first post."))
    }
}
