import Testing

@testable import NavigatorApp

@Suite("BlogLoader front-matter parser")
struct BlogLoaderTests {
    @Test("parses title, slug, author, and description from front-matter")
    func parsesCheckedInFixture() throws {
        let raw = """
            ---
            title: "Hello, World"
            author: "Neon Law Foundation"
            description: "Why the Neon Law Foundation is starting a blog."
            slug: "hello-world"
            ---

            Welcome to the Neon Law Foundation blog.
            """

        let post = try #require(try BlogLoader.parse(raw: raw, fallbackSlug: "fallback"))
        #expect(post.slug == "hello-world")
        #expect(post.title == "Hello, World")
        #expect(post.author == "Neon Law Foundation")
        #expect(post.description == "Why the Neon Law Foundation is starting a blog.")
        #expect(post.body.contains("Welcome to the Neon Law Foundation blog."))
    }

    @Test("falls back to provided slug when front-matter omits it")
    func usesFallbackSlug() throws {
        let raw = """
            ---
            title: "Untitled"
            ---

            Body.
            """

        let post = try #require(try BlogLoader.parse(raw: raw, fallbackSlug: "my-file"))
        #expect(post.slug == "my-file")
    }

    @Test("treats omitted author as empty so anonymous posts render bare")
    func treatsOmittedAuthorAsEmpty() throws {
        let raw = """
            ---
            title: "Anonymous"
            slug: "anon"
            ---

            body
            """

        let post = try #require(try BlogLoader.parse(raw: raw, fallbackSlug: "anon"))
        #expect(post.author == "")
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
    }

    @Test("loadAll returns posts sorted alphabetically by title (case-insensitive)")
    func loadAllSortsAlphabetically() throws {
        let posts = try BlogLoader.loadAll()
        let titles = posts.map(\.title)
        let sorted = titles.sorted(by: {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        })
        #expect(titles == sorted)
    }
}
