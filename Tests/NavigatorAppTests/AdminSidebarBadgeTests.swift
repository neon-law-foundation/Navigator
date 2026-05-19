import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Tests for the HTMX-driven sidebar unread-mail badge.
@Suite("Admin: Sidebar unread badge", .serialized)
struct AdminSidebarBadgeTests {

    @Test("admin pages include the #inbox-badge HTMX slot")
    func sidebarRendersBadgeSlot() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"id="inbox-badge""#))
                    #expect(
                        body.contains(
                            #"hx-get="/admin/api/sidebar-badges/inbox""#
                        )
                    )
                    #expect(body.contains(#"hx-trigger="load, every 30s""#))
                }
            )
        }
    }

    @Test("badge endpoint renders count > 0 when there are unread inbound rows")
    func badgeShowsUnreadCount() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let blob = Blob()
            blob.objectStorageUrl = "s3://test/badge-\(UUID().uuidString).eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let m = EmailMessage()
            m.messageId = "<badge-\(UUID().uuidString)@example.com>"
            m.threadId = m.messageId
            m.fromAddress = "outside@example.com"
            m.toAddress = "support@example.com"
            m.subject = "Badge unread"
            m.receivedAt = Date()
            m.$rawBlob.id = blob.id!
            m.spamVerdict = "PASS"
            m.virusVerdict = "PASS"
            m.dkimVerdict = "PASS"
            m.dmarcVerdict = "PASS"
            try await m.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/api/sidebar-badges/inbox",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(#"data-badge="inbox""#))
                    // Count is at least 1 — the seeded row plus any
                    // pre-existing inbound seeds.
                    #expect(!body.contains(#"data-count="0""#))
                }
            )
        }
    }

    @Test("badge endpoint emits an empty span when nothing is unread")
    func badgeIsBlankWhenZero() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            // Acknowledge every existing inbound message so the count
            // is forced to zero for this test.
            let inbound = try await EmailMessage.query(on: db).all()
            for m in inbound where m.direction == .inbound {
                m.acknowledgedAt = Date()
                try await m.save(on: db)
            }
            try await app.testing().test(
                .GET,
                "/admin/api/sidebar-badges/inbox",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-count="0""#))
                    // Visible chip classes (rose background) must not
                    // appear — the zero state is intentionally invisible.
                    #expect(!body.contains("bg-rose-500"))
                }
            )
        }
    }

    @Test("badge endpoint ignores outbound messages")
    func badgeIgnoresOutbound() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            // Drain inbound first so the count starts at zero.
            let inbound = try await EmailMessage.query(on: db).all()
            for m in inbound where m.direction == .inbound {
                m.acknowledgedAt = Date()
                try await m.save(on: db)
            }
            let blob = Blob()
            blob.objectStorageUrl = "s3://test/badge-out-\(UUID().uuidString).eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let outbound = EmailMessage()
            outbound.messageId = "<badge-out-\(UUID().uuidString)@example.com>"
            outbound.threadId = outbound.messageId
            outbound.fromAddress = "support@neonlaw.org"
            outbound.toAddress = "client@example.com"
            outbound.subject = "Outbound badge test"
            outbound.receivedAt = Date()
            outbound.$rawBlob.id = blob.id!
            outbound.spamVerdict = EmailMessage.outboundVerdictSentinel
            outbound.virusVerdict = EmailMessage.outboundVerdictSentinel
            outbound.dkimVerdict = EmailMessage.outboundVerdictSentinel
            outbound.dmarcVerdict = EmailMessage.outboundVerdictSentinel
            try await outbound.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/api/sidebar-badges/inbox",
                afterResponse: { res async in
                    #expect(res.body.string.contains(#"data-count="0""#))
                }
            )
        }
    }
}
