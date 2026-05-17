import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Tests that pin `www.neonlaw.com` as the single canonical hostname the
/// site advertises and redirects to. The legacy `.org` hostname must not
/// appear in any generated artifact (canonical URLs, og:url, og:image,
/// twitter:image, OpenAPI servers list, apex-redirect target).
@Suite("Canonical host is www.neonlaw.com", .serialized)
struct CanonicalHostTests {
    @Test("blog post canonical og:url points at www.neonlaw.com")
    func blogPostCanonicalIsDotCom() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/blog/hello-world",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string

                    #expect(
                        body.contains(
                            #"<meta property="og:url" content="https://www.neonlaw.com/blog/hello-world">"#
                        )
                    )
                    // The legacy canonical hostname must not appear in any
                    // generated absolute URL. `support@neonlaw.org` is a
                    // mailbox, not a site hostname, so it is unaffected.
                    #expect(!body.contains("www.neonlaw.org"))
                    #expect(!body.contains("https://neonlaw.org"))
                }
            )
        }
    }

    @Test("GET /openapi.yaml lists www.neonlaw.com in servers and not www.neonlaw.org")
    func openAPISpecListsDotComServer() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/openapi.yaml",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string

                    #expect(body.contains("https://www.neonlaw.com"))
                    #expect(!body.contains("https://www.neonlaw.org"))
                    // Sanity-check that what we're serving is actually the spec.
                    #expect(body.contains("openapi:"))
                    #expect(body.contains("servers:"))
                }
            )
        }
    }

    @Test("apex host neonlaw.com redirects to https://www.neonlaw.com preserving path")
    func apexRedirectsToWWW() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/blog",
                headers: ["host": "neonlaw.com"],
                afterResponse: { res async in
                    // Permanent redirect so search engines collapse the
                    // apex hostname into the www form.
                    #expect(res.status == .movedPermanently)
                    #expect(
                        res.headers.first(name: .location)
                            == "https://www.neonlaw.com/blog"
                    )
                }
            )
        }
    }

    @Test("apex root path redirects to https://www.neonlaw.com/")
    func apexRootRedirectsToWWW() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/",
                headers: ["host": "neonlaw.com"],
                afterResponse: { res async in
                    #expect(res.status == .movedPermanently)
                    #expect(
                        res.headers.first(name: .location)
                            == "https://www.neonlaw.com/"
                    )
                }
            )
        }
    }
}
