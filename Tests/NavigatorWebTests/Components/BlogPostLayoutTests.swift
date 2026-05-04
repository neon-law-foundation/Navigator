import Foundation
import Testing

@testable import NavigatorWeb

@Suite("BlogPostLayout")
struct BlogPostLayoutTests {
    private func fixturePost(body: String = "Body text.") -> BlogPost {
        BlogPost(
            slug: "hello-world",
            title: "Hello, world",
            date: Date(timeIntervalSince1970: 1_735_689_600),
            excerpt: "A first post.",
            tags: ["intro"],
            author: "Nick Shook",
            body: body
        )
    }

    @Test("composes header, post body, and footer in order")
    func composesAllSections() {
        let html = BlogPostLayout(
            post: fixturePost(),
            brand: NLFBrand(),
            authUser: nil
        ).render()

        guard
            let headerIndex = html.range(of: "<header"),
            let articleIndex = html.range(of: "<article"),
            let footerIndex = html.range(of: "<footer")
        else {
            Issue.record("expected header/article/footer markers in output")
            return
        }
        #expect(headerIndex.lowerBound < articleIndex.lowerBound)
        #expect(articleIndex.lowerBound < footerIndex.lowerBound)
    }

    @Test("renders the markdown body inside the post layout")
    func rendersMarkdownBody() {
        let html = BlogPostLayout(
            post: fixturePost(body: "A *paragraph* with **bold**."),
            brand: NLFBrand(),
            authUser: nil
        ).render()

        #expect(html.contains("<em>paragraph</em>"))
        #expect(html.contains("<strong>bold</strong>"))
        #expect(!html.contains("**bold**"))
    }
}
