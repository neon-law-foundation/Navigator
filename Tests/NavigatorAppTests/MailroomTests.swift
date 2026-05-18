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

    @Test("default sort renders header links targeting the portal's own path")
    func defaultSortHeaderLinksTargetSelf() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/portal/mailroom",
                afterResponse: { res async in
                    let body = res.body.string
                    // Active descending sort on receivedAt → clicking the
                    // Received header flips to ascending; other sortable
                    // headers link to their plain ascending form.
                    #expect(body.contains("href=\"/portal/mailroom?sort=receivedAt\""))
                    #expect(body.contains("href=\"/portal/mailroom?sort=sender\""))
                    #expect(body.contains("href=\"/portal/mailroom?sort=subject\""))
                }
            )
        }
    }

    @Test("?sort=receivedAt reverses the default and renders oldest letter first")
    func ascendingReceivedAtFlipsOrder() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/portal/mailroom?sort=receivedAt",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    guard
                        let older = body.range(of: "Notice of Intent to Lien")?.lowerBound,
                        let newer = body.range(
                            of: "Certified Copy of Articles of Organization"
                        )?.lowerBound
                    else {
                        Issue.record(
                            "expected the oldest and newest seeded subjects in the body"
                        )
                        return
                    }
                    #expect(older < newer)
                    // The active-sort link on the Received header should
                    // now point at the descending form.
                    #expect(body.contains("href=\"/portal/mailroom?sort=-receivedAt\""))
                }
            )
        }
    }

    @Test("?sort=-sender sorts by sender descending (Z to A)")
    func descendingSenderSorts() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/portal/mailroom?sort=-sender",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    // "USPTO" precedes "Bank of Carson Valley" alphabetically
                    // descending.
                    guard
                        let uspto = body.range(of: "USPTO")?.lowerBound,
                        let bank = body.range(of: "Bank of Carson Valley")?.lowerBound
                    else {
                        Issue.record("expected USPTO and Bank rows in the body")
                        return
                    }
                    #expect(uspto < bank)
                }
            )
        }
    }

    @Test("?sort=sender sorts by sender ascending (A to Z)")
    func ascendingSenderSorts() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/portal/mailroom?sort=sender",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    guard
                        let bank = body.range(of: "Bank of Carson Valley")?.lowerBound,
                        let uspto = body.range(of: "USPTO")?.lowerBound
                    else {
                        Issue.record("expected Bank and USPTO rows in the body")
                        return
                    }
                    #expect(bank < uspto)
                }
            )
        }
    }

    @Test("?sort=mailbox orders rows by the integer mailbox number")
    func mailboxSortIsNumeric() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/portal/mailroom?sort=mailbox",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    // Seeded mailboxes are 9001, 9014, 9022, 9033.
                    guard
                        let first = body.range(of: ">9001<")?.lowerBound,
                        let last = body.range(of: ">9033<")?.lowerBound
                    else {
                        Issue.record("expected mailbox numbers 9001 and 9033 in the body")
                        return
                    }
                    #expect(first < last)
                }
            )
        }
    }

    @Test("?sort=unknown is rejected with 400 per the JSON:API 1.1 sort MUST")
    func unknownSortReturns400() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/portal/mailroom?sort=unknown",
                afterResponse: { res async in
                    #expect(res.status == .badRequest)
                }
            )
        }
    }

    @Test("admin route honors ?sort= the same way as the portal route")
    func adminRouteHonorsSort() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/mailroom?sort=sender",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    // Admin links must target /admin/mailroom, not /portal/...
                    #expect(body.contains("href=\"/admin/mailroom?sort=-sender\""))
                    #expect(!body.contains("href=\"/portal/mailroom?sort="))
                }
            )
        }
    }
}
