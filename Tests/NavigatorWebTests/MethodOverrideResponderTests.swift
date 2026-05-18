import Testing
import Vapor
import VaporTesting

@testable import NavigatorWeb

/// Browsers only emit `GET` and `POST` from `<form>` elements, so admin
/// pages stage `PATCH` / `PUT` / `DELETE` actions as a `POST` carrying a
/// `_method` form field. ``MethodOverrideResponder`` rewrites the request
/// method so the rest of the routing layer sees the intended verb.
@Suite("MethodOverrideResponder", .serialized)
struct MethodOverrideMiddlewareTests {

    /// Boots a throwaway Vapor app, installs the responder wrap, registers
    /// a handler under every relevant HTTP method that echoes the verb the
    /// request arrived with, and lets the test body issue requests against
    /// it via `app.testing()`.
    private func withTestApp(
        _ body: @Sendable (Application) async throws -> Void
    ) async throws {
        let app = try await Application.make(.testing)
        do {
            // Echo handlers so each test can read back which method the
            // routing layer ultimately dispatched to. Routes are
            // registered BEFORE installing the responder wrap because
            // `app.responder.default` snapshots the routes table.
            app.on(.GET, "echo") { _ in "GET" }
            app.on(.POST, "echo") { _ in "POST" }
            app.on(.PATCH, "echo") { _ in "PATCH" }
            app.on(.PUT, "echo") { _ in "PUT" }
            app.on(.DELETE, "echo") { _ in "DELETE" }
            app.useMethodOverride()
            try await body(app)
            try await app.asyncShutdown()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }

    @Test("GET requests pass through unchanged")
    func getPassesThrough() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .GET,
                "/echo",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "GET")
                }
            )
        }
    }

    @Test("POST without _method stays a POST")
    func postWithoutOverrideStaysPost() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .POST,
                "/echo",
                beforeRequest: { req in
                    try req.content.encode(["codename": "alpha"], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "POST")
                }
            )
        }
    }

    @Test("POST with _method=DELETE is rewritten to DELETE")
    func postWithDeleteOverride() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .POST,
                "/echo",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "DELETE")
                }
            )
        }
    }

    @Test("POST with _method=PATCH is rewritten to PATCH")
    func postWithPatchOverride() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .POST,
                "/echo",
                beforeRequest: { req in
                    try req.content.encode(["_method": "PATCH"], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "PATCH")
                }
            )
        }
    }

    @Test("POST with _method=PUT is rewritten to PUT")
    func postWithPutOverride() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .POST,
                "/echo",
                beforeRequest: { req in
                    try req.content.encode(["_method": "PUT"], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "PUT")
                }
            )
        }
    }

    @Test("_method is case-insensitive")
    func methodOverrideIsCaseInsensitive() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .POST,
                "/echo",
                beforeRequest: { req in
                    try req.content.encode(["_method": "delete"], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "DELETE")
                }
            )
        }
    }

    @Test("_method=GET is rejected so a POST never downgrades into a GET")
    func getOverrideIsRejected() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .POST,
                "/echo",
                beforeRequest: { req in
                    try req.content.encode(["_method": "GET"], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "POST")
                }
            )
        }
    }

    @Test("garbage _method values are ignored")
    func garbageOverrideIsIgnored() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .POST,
                "/echo",
                beforeRequest: { req in
                    try req.content.encode(["_method": "TEAPOT"], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "POST")
                }
            )
        }
    }

    @Test("GET with _method=DELETE in the query string does not override")
    func overrideOnlyAppliesToPost() async throws {
        try await withTestApp { app in
            try await app.testing().test(
                .GET,
                "/echo?_method=DELETE",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "GET")
                }
            )
        }
    }
}
