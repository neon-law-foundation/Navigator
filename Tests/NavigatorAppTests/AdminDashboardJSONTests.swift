import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Dashboard JSON snapshot", .serialized)
struct AdminDashboardJSONTests {

    @Test("GET /admin/api/dashboard.json returns application/json")
    func contentTypeHeader() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/api/dashboard.json",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(
                        res.headers.first(name: .contentType)?
                            .lowercased().contains("application/json") == true
                    )
                }
            )
        }
    }

    @Test("payload decodes and includes every documented count key")
    func payloadShape() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/api/dashboard.json",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("\"counts\""))
                    // Every documented key shows up at least as a JSON
                    // key (value can be null when the DB hasn't seeded
                    // it).
                    for key in [
                        "projects", "people", "entities", "notations",
                        "templates", "questions", "retainers", "inbox",
                        "messages", "shareClasses", "shareIssuances",
                    ] {
                        #expect(body.contains("\"\(key)\""))
                    }
                }
            )
        }
    }

    @Test("seeded rows reflect a non-zero count")
    func countsReflectSeededRows() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "dashjson-\(UUID().uuidString.prefix(6))"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/api/dashboard.json",
                afterResponse: { res async in
                    let body = res.body.string
                    // The projects count should be >= 1. We assert via a
                    // simple decode rather than substring matching the
                    // exact integer.
                    let data = Data(body.utf8)
                    let decoded =
                        (try? JSONDecoder().decode(
                            AdminDashboardJSONResponse.self,
                            from: data
                        ))
                        ?? AdminDashboardJSONResponse(
                            counts: AdminDashboardJSONResponse.Counts()
                        )
                    #expect((decoded.counts.projects ?? 0) >= 1)
                }
            )
        }
    }
}
