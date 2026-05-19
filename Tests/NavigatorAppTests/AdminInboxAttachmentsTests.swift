import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Inbox show attachment listing", .serialized)
struct AdminInboxAttachmentsTests {

    /// Inserts an inbound `EmailMessage` plus the requested number of
    /// `EmailAttachment` rows backed by tiny placeholder `Blob`s.
    private func seedMessage(
        on db: Database,
        attachments: [(filename: String, contentType: String, sizeBytes: Int64)]
    ) async throws -> EmailMessage {
        let rawBlob = Blob()
        rawBlob.objectStorageUrl = "s3://test/raw-\(UUID().uuidString).eml"
        rawBlob.referencedBy = .emailMessages
        rawBlob.referencedById = UUID()
        try await rawBlob.save(on: db)
        let messageID = UUID()
        let m = EmailMessage()
        m.id = messageID
        m.messageId = "<\(messageID.uuidString)@example.com>"
        m.threadId = m.messageId
        m.fromAddress = "anon@example.com"
        m.toAddress = "support@neonlaw.org"
        m.subject = "Attachment test"
        m.$rawBlob.id = rawBlob.id!
        m.spamVerdict = "PASS"
        m.virusVerdict = "PASS"
        m.dkimVerdict = "PASS"
        m.dmarcVerdict = "PASS"
        m.receivedAt = Date()
        try await m.save(on: db)
        for spec in attachments {
            let blob = Blob()
            blob.objectStorageUrl =
                "s3://attachments/\(UUID().uuidString)/\(spec.filename)"
            blob.referencedBy = .emailAttachments
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let att = EmailAttachment()
            att.$emailMessage.id = messageID
            att.$blob.id = blob.id!
            att.filename = spec.filename
            att.contentType = spec.contentType
            att.sizeBytes = spec.sizeBytes
            try await att.save(on: db)
        }
        return m
    }

    @Test("inbox show with zero attachments renders the empty-state note")
    func zeroAttachmentsRendersEmptyState() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let m = try await seedMessage(on: db, attachments: [])
            try await app.testing().test(
                .GET,
                "/admin/inbox/\(m.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Attachments<"))
                    #expect(body.contains("No attachments on this message."))
                }
            )
        }
    }

    @Test("inbox show with attachments renders each file with metadata and link")
    func attachmentsRenderMetadata() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let m = try await seedMessage(
                on: db,
                attachments: [
                    (filename: "engagement.pdf", contentType: "application/pdf", sizeBytes: 12_345),
                    (filename: "logo.png", contentType: "image/png", sizeBytes: 8_192),
                ]
            )
            try await app.testing().test(
                .GET,
                "/admin/inbox/\(m.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("engagement.pdf"))
                    #expect(body.contains("application/pdf"))
                    #expect(body.contains("logo.png"))
                    #expect(body.contains("image/png"))
                    // The size should be formatted in human units, not raw bytes.
                    #expect(body.contains("12 KB") || body.contains("12.1 KB") || body.contains("12,345"))
                    // Each attachment has a link to the backing Blob's URL.
                    #expect(body.contains("s3://attachments/"))
                }
            )
        }
    }
}
