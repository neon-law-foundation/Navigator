import Foundation
import Testing

@testable import App

@Suite("BlogLoader front-matter parser")
struct BlogLoaderTests {
    @Test("parses title, slug, author, date, description, and tags from front-matter")
    func parsesCheckedInFixture() throws {
        let raw = """
            ---
            title: "Hello, World"
            date: "2026-04-17"
            author: "Neon Law Foundation"
            description: "Why the Neon Law Foundation is starting a blog."
            tags: ["announcements"]
            slug: "hello-world"
            ---

            Welcome to the Neon Law Foundation blog.
            """

        let post = try #require(try BlogLoader.parse(raw: raw, fallbackSlug: "fallback"))
        #expect(post.slug == "hello-world")
        #expect(post.title == "Hello, World")
        #expect(post.author == "Neon Law Foundation")
        #expect(post.description == "Why the Neon Law Foundation is starting a blog.")
        #expect(post.tags == ["announcements"])

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let expectedDate = formatter.date(from: "2026-04-17")
        #expect(post.date == expectedDate)

        #expect(post.body.contains("Welcome to the Neon Law Foundation blog."))
    }

    @Test("falls back to provided slug when front-matter omits it")
    func usesFallbackSlug() throws {
        let raw = """
            ---
            title: "Untitled"
            date: "2026-01-01"
            ---

            Body.
            """

        let post = try #require(try BlogLoader.parse(raw: raw, fallbackSlug: "my-file"))
        #expect(post.slug == "my-file")
    }

    @Test("parses list values with multiple tags")
    func parsesMultipleTags() throws {
        let raw = """
            ---
            title: "Multi"
            date: "2026-02-02"
            slug: "multi"
            tags: ["a", "b", "c"]
            ---

            body
            """

        let post = try #require(try BlogLoader.parse(raw: raw, fallbackSlug: "multi"))
        #expect(post.tags == ["a", "b", "c"])
    }

    @Test("returns nil for content without front-matter")
    func returnsNilWithoutFrontMatter() throws {
        let raw = "no front matter here"
        let post = try BlogLoader.parse(raw: raw, fallbackSlug: "x")
        #expect(post == nil)
    }

    @Test("loadAll reads the bundled hello-world post")
    func loadAllReadsBundledPost() throws {
        let posts = try BlogLoader.loadAll()
        let hello = try #require(posts.first(where: { $0.slug == "hello-world" }))
        #expect(hello.title == "Hello, World")
        #expect(hello.tags.contains("announcements"))
    }
}
