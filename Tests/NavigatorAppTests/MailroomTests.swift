import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Mail room routes", .serialized)
struct MailroomTests {
    @Test("GET /admin/mailroom lists seeded letters newest first")
    func adminListsSeededLetters() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/mailroom",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains("Mail Room"))
                    #expect(body.contains("Admin"))
                    // The seeded mailroom name shows up in the table.
                    #expect(body.contains("Ridgeview Mail Center"))
                    // Two seeded subjects from `Letter.yaml`.
                    #expect(body.contains("IRS Determination Letter"))
                    #expect(body.contains("Trademark Office Action"))
                    // Sender column.
                    #expect(body.contains("USPTO"))
                    // Mailbox number column renders the integer.
                    #expect(body.contains(">9022<"))
                    // Received column shows the UTC calendar date.
                    #expect(body.contains("2026-05-15"))
                    // …and only the date — the time-of-day and "UTC"
                    // qualifier from the previous format must be gone.
                    #expect(!body.contains("18:00"))
                    #expect(!body.contains(" UTC"))
                    // Newest seeded letter (2026-05-15) appears before the
                    // oldest seeded letter (2026-05-01) in the rendered HTML.
                    guard
                        let newer = body.range(
                            of: "Certified Copy of Articles of Organization"
                        )?.lowerBound,
                        let older = body.range(of: "Notice of Intent to Lien")?.lowerBound
                    else {
                        Issue.record("expected both seeded letters in mailroom body")
                        return
                    }
                    #expect(newer < older)
                }
            )
        }
    }

    @Test("GET /portal/mailroom renders the same letters under the portal label")
    func portalListsSameLetters() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/portal/mailroom",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains("Portal"))
                    #expect(body.contains("Ridgeview Mail Center"))
                    #expect(body.contains("IRS Determination Letter"))
                }
            )
        }
    }
}
