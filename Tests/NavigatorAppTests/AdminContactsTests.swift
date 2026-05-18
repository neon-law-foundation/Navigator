import FluentKit
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Contacts", .serialized)
struct AdminContactsTests {

    @Test("GET /admin/contacts shows both people and entity kinds")
    func indexListsBothKinds() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/contacts",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(">Contacts<"))
                    #expect(body.contains(#"data-kind="person""#))
                    #expect(body.contains(#"data-kind="entity""#))
                }
            )
        }
    }

    @Test("GET /admin/contacts?q=… filters by name substring")
    func filterByQuery() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let unique = "ZZTopUnique\(UUID().uuidString.prefix(4))"
            let person = Person()
            person.name = unique
            person.email = "\(unique.lowercased())@example.com"
            try await person.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/contacts?q=\(unique)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(unique))
                    // Filter excludes everyone else; "Search" form chrome
                    // still renders so make sure the substring really is
                    // the one row in the table — its href shows up.
                    #expect(body.contains(#"href="/admin/people/\#(person.id!.uuidString)""#))
                }
            )
        }
    }

    @Test("GET /admin/contacts?q=nothing-matches renders the empty branch")
    func filterWithNoMatches() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/contacts?q=does-not-exist-anywhere-\(UUID().uuidString)",
                afterResponse: { res async in
                    #expect(res.body.string.contains("No contacts matched"))
                }
            )
        }
    }
}
