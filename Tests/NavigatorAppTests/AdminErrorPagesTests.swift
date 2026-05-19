import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Chromed error pages", .serialized)
struct AdminErrorPagesTests {

    @Test("unknown /admin/* path returns 404 with admin chrome")
    func unknownAdminPathRendersChrome() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/this-route-does-not-exist-\(UUID().uuidString.prefix(6))",
                afterResponse: { res async in
                    #expect(res.status == .notFound)
                    let body = res.body.string
                    // The admin sidebar's dashboard entry is the cheapest
                    // proof the chrome rendered. Plain-text 404 wouldn't
                    // contain this.
                    #expect(body.contains(#"data-section="dashboard""#))
                    #expect(body.contains("We couldn't find that resource."))
                    #expect(body.contains(#"href="/admin""#))
                }
            )
        }
    }

    @Test("Abort 404 thrown from an admin route renders the chromed page")
    func abortNotFoundRendersChrome() async throws {
        try await withApp(configure: testConfigure) { app in
            // Loading an unknown project id triggers a thrown
            // Abort(.notFound) — exactly the path the middleware
            // should intercept.
            try await app.testing().test(
                .GET,
                "/admin/projects/\(UUID().uuidString)",
                afterResponse: { res async in
                    #expect(res.status == .notFound)
                    let body = res.body.string
                    #expect(body.contains(#"data-section="dashboard""#))
                    #expect(body.contains("Status 404"))
                }
            )
        }
    }

    @Test("Abort with .badRequest renders the 400-flavored title")
    func abortBadRequestRendersChrome() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects/not-a-uuid",
                afterResponse: { res async in
                    #expect(res.status == .badRequest)
                    let body = res.body.string
                    #expect(body.contains(#"data-section="dashboard""#))
                    #expect(body.contains("That request looked off."))
                }
            )
        }
    }

    @Test("non-admin paths are not intercepted")
    func nonAdminPathsFallThrough() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/this-path-does-not-exist",
                afterResponse: { res async in
                    #expect(res.status == .notFound)
                    let body = res.body.string
                    // No admin chrome on public-site 404s.
                    #expect(!body.contains(#"data-section="dashboard""#))
                }
            )
        }
    }
}
