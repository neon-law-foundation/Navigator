import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("AdminPagination value type")
struct AdminPaginationValueTests {

    @Test("slice returns the first page by default")
    func sliceFirstPage() {
        let rows = Array(1...125)
        let sliced = AdminPagination.slice(rows, page: 1, pageSize: 50)
        #expect(sliced.first == 1)
        #expect(sliced.last == 50)
        #expect(sliced.count == 50)
    }

    @Test("slice returns the right window for page 2")
    func sliceSecondPage() {
        let rows = Array(1...125)
        let sliced = AdminPagination.slice(rows, page: 2, pageSize: 50)
        #expect(sliced.first == 51)
        #expect(sliced.last == 100)
    }

    @Test("slice clamps the last page to the row count")
    func sliceLastPage() {
        let rows = Array(1...125)
        let sliced = AdminPagination.slice(rows, page: 3, pageSize: 50)
        #expect(sliced.first == 101)
        #expect(sliced.last == 125)
        #expect(sliced.count == 25)
    }

    @Test("slice returns an empty array beyond the last page")
    func sliceBeyondLastPage() {
        let rows = Array(1...125)
        #expect(AdminPagination.slice(rows, page: 99, pageSize: 50).isEmpty)
    }

    @Test("parsePage clamps invalid values to 1")
    func parsePageClamps() {
        #expect(AdminPagination.parsePage(nil) == 1)
        #expect(AdminPagination.parsePage("0") == 1)
        #expect(AdminPagination.parsePage("-3") == 1)
        #expect(AdminPagination.parsePage("not a number") == 1)
        #expect(AdminPagination.parsePage("4") == 4)
    }

    @Test("startIndex and endIndex reflect 1-indexed row positions")
    func indices() {
        let pag = AdminPagination(
            page: 2,
            pageSize: 50,
            total: 125,
            basePath: "/x",
            queryItems: []
        )
        #expect(pag.startIndex == 51)
        #expect(pag.endIndex == 100)
        #expect(pag.hasPrev == true)
        #expect(pag.hasNext == true)
    }

    @Test("hasNext is false when on the last partial page")
    func hasNextLastPage() {
        let pag = AdminPagination(
            page: 3,
            pageSize: 50,
            total: 125,
            basePath: "/x",
            queryItems: []
        )
        #expect(pag.hasNext == false)
        #expect(pag.hasPrev == true)
    }

    @Test("Prev/Next href preserves query items in alphabetical order")
    func prevNextHrefPreservesQueryItems() {
        let pag = AdminPagination(
            page: 2,
            pageSize: 50,
            total: 125,
            basePath: "/admin/inbox",
            queryItems: [("sort", "-receivedAt"), ("q", "needle")]
        )
        let html = AdminPaginationFooter(pagination: pag).render()
        // q sorts before sort alphabetically; both come before the page key.
        #expect(html.contains(#"/admin/inbox?q=needle&amp;sort=-receivedAt&amp;page=1"#))
        #expect(html.contains(#"/admin/inbox?q=needle&amp;sort=-receivedAt&amp;page=3"#))
    }
}

@Suite("Admin: Pagination on /admin/projects", .serialized)
struct AdminProjectsPaginationTests {

    @Test("projects index hides the footer when total <= pageSize")
    func footerHiddenForSmallList() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects",
                afterResponse: { res async in
                    #expect(!res.body.string.contains(#"data-pagination="true""#))
                }
            )
        }
    }

    @Test("projects index shows the footer when total > pageSize")
    func footerShownAfterSeedingPastPageSize() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            // Seed 51 rows (pageSize is 50) so pagination kicks in.
            for i in 0..<51 {
                let p = Project()
                p.codename = "page-seed-\(i)-\(UUID().uuidString.prefix(4))"
                try await p.save(on: db)
            }
            try await app.testing().test(
                .GET,
                "/admin/projects",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-pagination="true""#))
                    // Default sort is codename ascending; "page-seed-0…"
                    // sorts before the original two seeded projects? Not
                    // necessarily, but a Next link should exist with
                    // ?page=2.
                    #expect(body.contains("page=2"))
                }
            )
        }
    }

    @Test("?page=2 returns rows past the first page")
    func secondPageReturnsLaterRows() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            // Two recognisable rows we can pin to specific page slots.
            let marker = "ZZZZZ-marker-\(UUID().uuidString.prefix(4))"
            // Seed 51 rows; alphabetically the marker codename sorts last
            // so it should land on page 2.
            for i in 0..<50 {
                let p = Project()
                p.codename = "aaa-\(i)-\(UUID().uuidString.prefix(4))"
                try await p.save(on: db)
            }
            let last = Project()
            last.codename = marker
            try await last.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects?page=2",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(marker))
                }
            )
        }
    }
}
