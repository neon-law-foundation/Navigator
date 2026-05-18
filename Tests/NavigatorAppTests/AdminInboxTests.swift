import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Inbox", .serialized)
struct AdminInboxTests {

    @Test("GET /admin/inbox renders")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/inbox",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">Inbox<"))
                }
            )
        }
    }

    @Test("POST /admin/inbox/:id/acknowledge stamps acknowledgedAt")
    func acknowledgeStampsTimestamp() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let blob = Blob()
            blob.objectStorageUrl = "s3://test/raw.eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let m = EmailMessage()
            m.messageId = "<test-\(UUID().uuidString)@example.com>"
            m.threadId = m.messageId
            m.fromAddress = "sender@example.com"
            m.toAddress = "support@example.com"
            m.subject = "Test ack"
            m.$rawBlob.id = blob.id!
            m.spamVerdict = "PASS"
            m.virusVerdict = "PASS"
            m.dkimVerdict = "PASS"
            m.dmarcVerdict = "PASS"
            m.receivedAt = Date()
            try await m.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/inbox/\(m.id!.uuidString)/acknowledge",
                afterResponse: { _ in }
            )
            let reloaded = try await EmailMessage.find(m.id!, on: db)
            #expect(reloaded?.acknowledgedAt != nil)
        }
    }

    @Test("GET /admin/messages renders the placeholder page")
    func messagesPlaceholder() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/messages",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Outbound messaging is not wired up yet."))
                }
            )
        }
    }
}
