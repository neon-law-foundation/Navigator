import Foundation
import Testing

@testable import NavigatorWeb

@Suite("BlogPostPage")
struct BlogPostPageTests {
    private func fixturePost(tags: [String] = ["intro"], body: String = "Hello body.") -> BlogPost {
        BlogPost(
            slug: "hello-world",
            title: "Hello, world",
            date: Date(timeIntervalSince1970: 1_735_689_600),
            excerpt: "A first post.",
            tags: tags,
            author: "Nick Shook",
            body: body
        )
    }

    @Test("renders title, date, author, and rendered body")
    func rendersHeaderAndBody() {
        let html = BlogPostPage(post: fixturePost(), brand: NLFBrand()).render()

        #expect(html.contains("<h1"))
        #expect(html.contains("Hello, world"))
        #expect(html.contains("2025-01-01"))
        #expect(html.contains("Nick Shook"))
        // Body markdown wraps as a <p> via renderMarkdown.
        #expect(html.contains("<p>Hello body.</p>"))
    }

    @Test("renders tag chips when tags are present")
    func rendersTagChips() {
        let html = BlogPostPage(
            post: fixturePost(tags: ["alpha", "beta"]),
            brand: NLFBrand()
        ).render()

        #expect(html.contains(">alpha<"))
        #expect(html.contains(">beta<"))
    }

    @Test("renders no tag chips when tags is empty")
    func rendersNoTagChipsWhenEmpty() {
        let html = BlogPostPage(post: fixturePost(tags: []), brand: NLFBrand()).render()

        #expect(!html.contains(">intro<"))
    }

    @Test("body markdown is rendered to HTML, not emitted as raw source")
    func bodyMarkdownIsRendered() {
        let body = "# Heading\n\nA *paragraph* with **bold**."
        let html = BlogPostPage(post: fixturePost(body: body), brand: NLFBrand()).render()

        // M3 visitor produces these tags from inline + heading nodes.
        #expect(html.contains("<h1>Heading</h1>"))
        #expect(html.contains("<em>paragraph</em>"))
        #expect(html.contains("<strong>bold</strong>"))
        // The raw markdown source must NOT appear verbatim.
        #expect(!html.contains("# Heading"))
        #expect(!html.contains("**bold**"))
    }
}
