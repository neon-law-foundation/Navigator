import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Projects sort + filter", .serialized)
struct AdminProjectsSortFilterTests {

    @Test("index renders sortable headers with the default codename sort active")
    func sortableHeaders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects",
                afterResponse: { res async in
                    let body = res.body.string
                    // Each sortable column header is a link with ?sort=
                    #expect(body.contains(#"data-column-key="codename""#))
                    #expect(body.contains(#"data-column-key="title""#))
                    #expect(body.contains(#"data-column-key="status""#))
                    #expect(body.contains(#"data-column-key="projectType""#))
                    // Default sort flips codename to descending on click.
                    #expect(body.contains(#"href="/admin/projects?sort=-codename""#))
                }
            )
        }
    }

    @Test("?sort=title flips the title column's link to descending")
    func sortFlipsActive() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects?sort=title",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"href="/admin/projects?sort=-title""#))
                }
            )
        }
    }

    @Test("?sort=unknown is rejected with 400")
    func unknownSortReturns400() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects?sort=unknown",
                afterResponse: { res async in
                    #expect(res.status == .badRequest)
                }
            )
        }
    }

    @Test("filter input renders with the active query value")
    func filterInputRendersValue() async throws {
        try await withApp(configure: testConfigure) { app in
            // Seed a row that matches "alpha" so the table renders (and
            // therefore the sort links exist for the assertion below).
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "alpha-\(UUID().uuidString.prefix(6))"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects?q=alpha",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"value="alpha""#))
                    // Sort links carry the q forward so a click keeps the
                    // operator's filter.
                    #expect(body.contains(#"q=alpha&amp;sort="#))
                }
            )
        }
    }

    @Test("?q= filter narrows the list to substring matches on codename or title")
    func filterFiltersRows() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let needle = "needle-\(UUID().uuidString.prefix(6))"
            let included = Project()
            included.codename = needle
            included.title = "Match"
            try await included.save(on: db)
            let excluded = Project()
            excluded.codename = "haystack-\(UUID().uuidString.prefix(6))"
            excluded.title = "No match"
            try await excluded.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects?q=\(needle)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(needle))
                    #expect(!body.contains(excluded.codename))
                }
            )
        }
    }

    @Test("filter with no matches shows the empty branch with the search term")
    func filterNoMatchesEmptyState() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects?q=zzz-no-match-\(UUID().uuidString)",
                afterResponse: { res async in
                    #expect(res.body.string.contains("No projects matched"))
                }
            )
        }
    }
}
