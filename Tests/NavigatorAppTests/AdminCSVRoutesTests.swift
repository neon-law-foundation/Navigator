import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Smoke tests for `?format=csv` on the five admin index pages that
/// support export. Each page asserts on three invariants:
///
/// 1. `Content-Type: text/csv; charset=utf-8` on the response.
/// 2. `Content-Disposition: attachment; filename="<resource>-YYYY-MM-DD.csv"`.
/// 3. The body starts with the expected header row.
///
/// Per-page deep tests (column content, escaping, etc.) live in the
/// existing `AdminCSVExportValueTests` suite and the resource's own
/// route tests.
@Suite("Admin: CSV export routes", .serialized)
struct AdminCSVRoutesTests {

    private struct PageSpec {
        let path: String
        let resource: String
        let headerPrefix: String
    }

    private static let pages: [PageSpec] = [
        PageSpec(path: "/admin/projects", resource: "projects", headerPrefix: "Codename,Title"),
        PageSpec(path: "/admin/people", resource: "people", headerPrefix: "Name,Email"),
        PageSpec(path: "/admin/entities", resource: "entities", headerPrefix: "Name,Type"),
        PageSpec(
            path: "/admin/inbox",
            resource: "inbox",
            headerPrefix: "Received,From,To,Subject,Acknowledged"
        ),
        PageSpec(
            path: "/admin/messages",
            resource: "messages",
            headerPrefix: "Sent,To,Subject"
        ),
    ]

    @Test("?format=csv returns text/csv with the right Content-Disposition")
    func returnsCSVResponseHeaders() async throws {
        try await withApp(configure: testConfigure) { app in
            for page in Self.pages {
                try await app.testing().test(
                    .GET,
                    "\(page.path)?format=csv",
                    afterResponse: { res async in
                        #expect(
                            res.headers.first(name: .contentType) == "text/csv; charset=utf-8",
                            "\(page.path) should serve text/csv"
                        )
                        let disposition = res.headers.first(name: .contentDisposition) ?? ""
                        #expect(
                            disposition.contains(#"filename="\#(page.resource)-"#),
                            "\(page.path) Content-Disposition should suggest <resource>- prefix"
                        )
                        #expect(disposition.contains(".csv\""))
                    }
                )
            }
        }
    }

    @Test("?format=csv body starts with the expected header row")
    func bodyStartsWithHeaderRow() async throws {
        try await withApp(configure: testConfigure) { app in
            for page in Self.pages {
                try await app.testing().test(
                    .GET,
                    "\(page.path)?format=csv",
                    afterResponse: { res async in
                        let body = res.body.string
                        #expect(
                            body.hasPrefix(page.headerPrefix),
                            "\(page.path) CSV should start with \(page.headerPrefix); got: \(body.prefix(80))"
                        )
                    }
                )
            }
        }
    }

    @Test("?format=csv on /admin/projects honors the ?q= filter")
    func projectsCSVHonorsFilter() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let needle = "csvfilter-\(UUID().uuidString.prefix(6))"
            let p = Project()
            p.codename = needle
            p.title = "CSV filter test"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects?format=csv&q=\(needle)",
                afterResponse: { res async in
                    let body = res.body.string
                    // Should contain only the header + the matching row.
                    #expect(body.contains(needle))
                    let lineCount = body.components(separatedBy: "\r\n")
                        .filter { !$0.isEmpty }
                        .count
                    #expect(lineCount == 2, "header + one data row; got \(lineCount) lines")
                }
            )
        }
    }
}
