import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Smoke-coverage for the sort + filter pass applied to the remaining
/// admin index pages. Each page asserts on three invariants:
///
/// 1. `?sort=unknown` returns `400` per the JSON:API MUST.
/// 2. Each sortable column emits a header link with `data-column-key=<key>`.
/// 3. The `?q=` filter input round-trips into the rendered `value="…"`.
///
/// Per-page tests live alongside their existing routes (created,
/// edited, deleted, etc.); this suite only catches sort+filter wiring
/// regressions across the eight pages updated in this PR.
@Suite("Admin: sort + filter on remaining index pages", .serialized)
struct AdminSortFilterRestTests {

    private struct PageSpec {
        let path: String
        let columnKeys: [String]
    }

    private static let pages: [PageSpec] = [
        PageSpec(path: "/admin/entity-types", columnKeys: ["name", "jurisdiction"]),
        PageSpec(path: "/admin/jurisdictions", columnKeys: ["name", "code", "type"]),
        PageSpec(
            path: "/admin/credentials",
            columnKeys: ["person", "jurisdiction", "licenseNumber"]
        ),
        PageSpec(path: "/admin/mailrooms", columnKeys: ["name", "mailboxStart"]),
        PageSpec(path: "/admin/questions", columnKeys: ["code", "prompt", "questionType"]),
        PageSpec(path: "/admin/notations", columnKeys: ["template", "state"]),
        PageSpec(path: "/admin/templates", columnKeys: ["title", "code", "version"]),
        PageSpec(path: "/admin/messages", columnKeys: ["sent", "to", "subject"]),
    ]

    @Test("?sort=unknown returns 400 on every retrofit page")
    func unknownSortRejected() async throws {
        try await withApp(configure: testConfigure) { app in
            for page in Self.pages {
                try await app.testing().test(
                    .GET,
                    "\(page.path)?sort=unknown",
                    afterResponse: { res async in
                        #expect(
                            res.status == .badRequest,
                            "\(page.path) should reject ?sort=unknown with 400"
                        )
                    }
                )
            }
        }
    }

    @Test("each retrofit page renders sortable headers with data-column-key")
    func sortableHeadersRender() async throws {
        try await withApp(configure: testConfigure) { app in
            // /admin/messages has no seeded outbound rows by default, so
            // the table (and its sort headers) won't render until we
            // create one. The other pages all have seed rows already.
            let db = try await app.databaseService!.db
            _ = try await EmailMessageRepository(database: db).createOutbound(
                to: "smoke-\(UUID().uuidString.prefix(4))@example.com",
                from: "support@neonlaw.org",
                subject: "Smoke test for sort headers",
                textBody: "x"
            )
            for page in Self.pages {
                try await app.testing().test(
                    .GET,
                    page.path,
                    afterResponse: { res async in
                        let body = res.body.string
                        for key in page.columnKeys {
                            #expect(
                                body.contains(#"data-column-key="\#(key)""#),
                                "\(page.path) missing data-column-key=\"\(key)\""
                            )
                        }
                    }
                )
            }
        }
    }

    @Test("?q= input renders with the active value on every retrofit page")
    func filterInputRendersValue() async throws {
        try await withApp(configure: testConfigure) { app in
            for page in Self.pages {
                try await app.testing().test(
                    .GET,
                    "\(page.path)?q=testfilter",
                    afterResponse: { res async in
                        let body = res.body.string
                        #expect(
                            body.contains(#"value="testfilter""#),
                            "\(page.path) did not echo the active q= value into the filter input"
                        )
                    }
                )
            }
        }
    }
}
