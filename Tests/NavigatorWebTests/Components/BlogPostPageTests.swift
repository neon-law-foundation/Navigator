import Testing

@testable import NavigatorWeb

@Suite("BlogPostPage")
struct BlogPostPageTests {
    private func fixturePost(author: String = "Nick Shook", body: String = "Hello body.") -> BlogPost {
        BlogPost(
            slug: "hello-world",
            title: "Hello, world",
            excerpt: "A first post.",
            author: author,
            body: body
        )
    }

    @Test("renders title, author, and rendered body")
    func rendersHeaderAndBody() {
        let html = BlogPostPage(post: fixturePost(), brand: NLFBrand()).render()

        #expect(html.contains("<h1"))
        #expect(html.contains("Hello, world"))
        #expect(html.contains("Nick Shook"))
        // Body markdown wraps as a <p> via renderMarkdown.
        #expect(html.contains("<p>Hello body.</p>"))
    }

    @Test("omits author line when author is empty")
    func omitsEmptyAuthor() {
        let html = BlogPostPage(post: fixturePost(author: ""), brand: NLFBrand()).render()

        #expect(!html.contains("text-sm text-gray-500"))
        #expect(html.contains("Hello, world"))
    }

    @Test("body markdown is rendered to HTML, not emitted as raw source")
    func bodyMarkdownIsRendered() {
        let body = "# Heading\n\nA *paragraph* with **bold**."
        let html = BlogPostPage(post: fixturePost(body: body), brand: NLFBrand()).render()

        #expect(html.contains("<h1>Heading</h1>"))
        #expect(html.contains("<em>paragraph</em>"))
        #expect(html.contains("<strong>bold</strong>"))
        #expect(!html.contains("# Heading"))
        #expect(!html.contains("**bold**"))
    }
}
