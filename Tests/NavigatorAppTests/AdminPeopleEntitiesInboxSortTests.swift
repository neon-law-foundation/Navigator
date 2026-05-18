import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: People sort + filter", .serialized)
struct AdminPeopleSortFilterTests {

    @Test("index renders sortable name + email headers, default sort=name asc")
    func sortableHeaders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/people",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-column-key="name""#))
                    #expect(body.contains(#"data-column-key="email""#))
                    #expect(body.contains(#"href="/admin/people?sort=-name""#))
                }
            )
        }
    }

    @Test("?sort=unknown is rejected with 400")
    func unknownSortReturns400() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/people?sort=unknown",
                afterResponse: { res async in #expect(res.status == .badRequest) }
            )
        }
    }

    @Test("?q= filters by name or email")
    func filterFiltersRows() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let needle = "needlename-\(UUID().uuidString.prefix(6))"
            let included = Person()
            included.name = needle
            included.email = "\(needle.lowercased())@example.com"
            try await included.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/people?q=\(needle)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(needle))
                    #expect(body.contains(#"value="\#(needle)""#))
                }
            )
        }
    }
}

@Suite("Admin: Entities sort + filter", .serialized)
struct AdminEntitiesSortFilterTests {

    @Test("index renders sortable name + type headers, default sort=name asc")
    func sortableHeaders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/entities",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-column-key="name""#))
                    #expect(body.contains(#"data-column-key="type""#))
                    #expect(body.contains(#"href="/admin/entities?sort=-name""#))
                }
            )
        }
    }

    @Test("?sort=unknown is rejected with 400")
    func unknownSortReturns400() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/entities?sort=unknown",
                afterResponse: { res async in #expect(res.status == .badRequest) }
            )
        }
    }

    @Test("?q= filters by name")
    func filterFiltersRows() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entityType = try await EntityType.query(on: db).first()
            try #require(entityType != nil)
            let needle = "entityneedle-\(UUID().uuidString.prefix(6))"
            let e = Entity()
            e.name = needle
            e.$legalEntityType.id = entityType!.id!
            try await e.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/entities?q=\(needle)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(needle))
                    #expect(body.contains(#"value="\#(needle)""#))
                }
            )
        }
    }
}

@Suite("Admin: Inbox sort + filter", .serialized)
struct AdminInboxSortFilterTests {

    @Test("index renders sortable received/from/subject, default sort=-receivedAt")
    func sortableHeaders() async throws {
        try await withApp(configure: testConfigure) { app in
            // Seed an inbound row so the table renders (and the sort
            // links exist for the assertion).
            try await seedInbound(app: app, subject: "Seed for sort headers")
            try await app.testing().test(
                .GET,
                "/admin/inbox",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-column-key="receivedAt""#))
                    #expect(body.contains(#"data-column-key="from""#))
                    #expect(body.contains(#"data-column-key="subject""#))
                    // Active descending default flips to ascending on click.
                    #expect(body.contains(#"href="/admin/inbox?sort=receivedAt""#))
                }
            )
        }
    }

    /// Inserts one inbound `EmailMessage` row with PASS verdicts so the
    /// inbox index renders its table.
    private func seedInbound(app: Application, subject: String) async throws {
        let db = try await app.databaseService!.db
        let blob = Blob()
        blob.objectStorageUrl = "s3://test/raw.eml"
        blob.referencedBy = .emailMessages
        blob.referencedById = UUID()
        try await blob.save(on: db)
        let m = EmailMessage()
        m.messageId = "<\(UUID().uuidString)@example.com>"
        m.threadId = m.messageId
        m.fromAddress = "sender@example.com"
        m.toAddress = "support@neonlaw.org"
        m.subject = subject
        m.$rawBlob.id = blob.id!
        m.spamVerdict = "PASS"
        m.virusVerdict = "PASS"
        m.dkimVerdict = "PASS"
        m.dmarcVerdict = "PASS"
        m.receivedAt = Date()
        try await m.save(on: db)
    }

    @Test("?sort=unknown is rejected with 400")
    func unknownSortReturns400() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/inbox?sort=unknown",
                afterResponse: { res async in #expect(res.status == .badRequest) }
            )
        }
    }

    @Test("?q= filters by subject or sender")
    func filterFiltersRows() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let needle = "inboxneedle-\(UUID().uuidString.prefix(6))"
            let blob = Blob()
            blob.objectStorageUrl = "s3://test/raw.eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let m = EmailMessage()
            m.messageId = "<\(UUID().uuidString)@example.com>"
            m.threadId = m.messageId
            m.fromAddress = "sender@example.com"
            m.toAddress = "support@neonlaw.org"
            m.subject = "Subject with \(needle) in it"
            m.$rawBlob.id = blob.id!
            m.spamVerdict = "PASS"
            m.virusVerdict = "PASS"
            m.dkimVerdict = "PASS"
            m.dmarcVerdict = "PASS"
            m.receivedAt = Date()
            try await m.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/inbox?q=\(needle)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(needle))
                }
            )
        }
    }
}
