import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Bulk acknowledge on inbox", .serialized)
struct AdminInboxBulkTests {

    private func seedInbound(db: Database, subject: String) async throws -> EmailMessage {
        let blob = Blob()
        blob.objectStorageUrl = "s3://test/raw-\(UUID().uuidString).eml"
        blob.referencedBy = .emailMessages
        blob.referencedById = UUID()
        try await blob.save(on: db)
        let m = EmailMessage()
        m.messageId = "<\(UUID().uuidString)@example.com>"
        m.threadId = m.messageId
        m.fromAddress = "anon@example.com"
        m.toAddress = "support@neonlaw.org"
        m.subject = subject
        m.$rawBlob.id = blob.id!
        m.spamVerdict = "PASS"
        m.virusVerdict = "PASS"
        m.dkimVerdict = "PASS"
        m.dmarcVerdict = "PASS"
        m.receivedAt = Date()
        try await m.save(on: db)
        return m
    }

    @Test("inbox index renders per-row checkboxes and the bulk-action form")
    func indexRendersBulkAffordance() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            _ = try await seedInbound(db: db, subject: "Bulk seed")
            try await app.testing().test(
                .GET,
                "/admin/inbox",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"action="/admin/inbox/acknowledge-bulk""#))
                    #expect(body.contains(#"name="ids[]""#))
                    #expect(body.contains(#"type="checkbox""#))
                    #expect(body.contains("Acknowledge selected"))
                }
            )
        }
    }

    @Test("POST acknowledge-bulk stamps acknowledgedAt on every selected row")
    func bulkAcknowledgeStampsTimestamp() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let a = try await seedInbound(db: db, subject: "Bulk A")
            let b = try await seedInbound(db: db, subject: "Bulk B")
            let c = try await seedInbound(db: db, subject: "Bulk C")
            // Acknowledge a and c; leave b alone.
            let body = "ids[]=\(a.id!.uuidString)&ids[]=\(c.id!.uuidString)"
            var headers = HTTPHeaders()
            headers.replaceOrAdd(
                name: .contentType,
                value: "application/x-www-form-urlencoded"
            )
            try await app.testing().test(
                .POST,
                "/admin/inbox/acknowledge-bulk",
                headers: headers,
                body: ByteBuffer(string: body),
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/inbox") == true)
                }
            )
            #expect(try await EmailMessage.find(a.id!, on: db)?.acknowledgedAt != nil)
            #expect(try await EmailMessage.find(b.id!, on: db)?.acknowledgedAt == nil)
            #expect(try await EmailMessage.find(c.id!, on: db)?.acknowledgedAt != nil)
        }
    }

    @Test("POST acknowledge-bulk with no ids is a no-op redirect")
    func emptyBulkIsNoop() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .POST,
                "/admin/inbox/acknowledge-bulk",
                beforeRequest: { req in
                    try req.content.encode([String: String](), as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/inbox") == true)
                }
            )
        }
    }
}

@Suite("Admin: Bulk archive on projects", .serialized)
struct AdminProjectsBulkTests {

    @Test("projects index renders per-row checkboxes and the bulk-archive form")
    func indexRendersBulkAffordance() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "bulk-\(UUID().uuidString.prefix(6))"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"action="/admin/projects/archive-bulk""#))
                    #expect(body.contains(#"name="ids[]""#))
                    #expect(body.contains("Archive selected"))
                }
            )
        }
    }

    @Test("POST archive-bulk sets status=.archived on every selected row")
    func bulkArchiveSetsStatus() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let a = Project()
            a.codename = "barc-a-\(UUID().uuidString.prefix(4))"
            a.status = .active
            try await a.save(on: db)
            let b = Project()
            b.codename = "barc-b-\(UUID().uuidString.prefix(4))"
            b.status = .active
            try await b.save(on: db)
            let c = Project()
            c.codename = "barc-c-\(UUID().uuidString.prefix(4))"
            c.status = .active
            try await c.save(on: db)
            // Archive a and b; leave c alone.
            let body = "ids[]=\(a.id!.uuidString)&ids[]=\(b.id!.uuidString)"
            var headers = HTTPHeaders()
            headers.replaceOrAdd(
                name: .contentType,
                value: "application/x-www-form-urlencoded"
            )
            try await app.testing().test(
                .POST,
                "/admin/projects/archive-bulk",
                headers: headers,
                body: ByteBuffer(string: body),
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/projects") == true)
                }
            )
            #expect(try await Project.find(a.id!, on: db)?.status == .archived)
            #expect(try await Project.find(b.id!, on: db)?.status == .archived)
            #expect(try await Project.find(c.id!, on: db)?.status == .active)
        }
    }
}
