import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Blog routes", .serialized)
struct BlogTests {
    @Test("GET /blog lists the hello-world post")
    func indexListsPost() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/blog",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Hello, World"))
                    #expect(res.body.string.contains("hello-world"))
                }
            )
        }
    }

    @Test("GET /blog/hello-world renders the post body")
    func postPageRendersBody() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/blog/hello-world",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Welcome to the Neon Law Foundation blog"))
                    #expect(res.body.string.contains("announcements"))
                }
            )
        }
    }

    @Test("GET /blog/nonexistent returns 404")
    func unknownSlugIs404() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/blog/this-post-does-not-exist",
                afterResponse: { res async in
                    #expect(res.status == .notFound)
                }
            )
        }
    }
}
