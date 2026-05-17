import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Open Graph and Twitter card metadata", .serialized)
struct OpenGraphTests {
    @Test("blog post page emits article-typed Open Graph tags with the canonical URL")
    func blogPostEmitsArticleOG() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/blog/hello-world",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string

                    #expect(body.contains(#"<meta property="og:type" content="article">"#))
                    #expect(body.contains(#"<meta property="og:title" content="Hello, World">"#))
                    #expect(
                        body.contains(
                            #"<meta property="og:url" content="https://www.neonlaw.com/blog/hello-world">"#
                        )
                    )
                    #expect(body.contains(#"<meta property="og:site_name" content="Neon Law Foundation">"#))
                }
            )
        }
    }

    @Test("blog index page emits website-typed Open Graph tags with the /blog canonical URL")
    func blogIndexEmitsWebsiteOG() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/blog",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string

                    #expect(body.contains(#"<meta property="og:type" content="website">"#))
                    #expect(body.contains(#"<meta property="og:url" content="https://www.neonlaw.com/blog">"#))
                }
            )
        }
    }

    @Test("every blog post advertises the SVG logo first, then the PNG fallback")
    func blogPostAdvertisesLogoImages() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/blog/hello-world",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string

                    let svgTag = #"<meta property="og:image" content="https://www.neonlaw.com/logo.svg">"#
                    let pngTag = #"<meta property="og:image" content="https://www.neonlaw.com/logo.png">"#
                    #expect(body.contains(svgTag))
                    #expect(body.contains(pngTag))

                    guard
                        let svgRange = body.range(of: svgTag),
                        let pngRange = body.range(of: pngTag)
                    else {
                        Issue.record("expected both og:image tags in body")
                        return
                    }
                    #expect(svgRange.lowerBound < pngRange.lowerBound)
                }
            )
        }
    }

    @Test("Twitter card uses the PNG logo because X does not render SVG previews")
    func twitterCardUsesPNG() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/blog/hello-world",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string

                    #expect(body.contains(#"<meta name="twitter:card" content="summary">"#))
                    #expect(
                        body.contains(
                            #"<meta name="twitter:image" content="https://www.neonlaw.com/logo.png">"#
                        )
                    )
                }
            )
        }
    }

    @Test("no published-time or article-time metadata is emitted")
    func noTimestampMetadata() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/blog/hello-world",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string

                    #expect(!body.contains("article:published_time"))
                    #expect(!body.contains("article:modified_time"))
                    #expect(!body.contains("og:published_time"))
                }
            )
        }
    }
}
