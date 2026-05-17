import Fluent
import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import Testing
import Vapor

@Suite(
    "EmailMessage Database Operations",
    .disabled(
        if: isUsingPostgresMode(),
        "Model encodes jsonb columns as text; Postgres rejects until the model is fixed."
    )
)
struct EmailMessageTests {

    @Test("Repository creates raw blob, message, and attachment rows in one call")
    func testCreatePersistsMessageAndAttachments() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)
            let message = makeMessage(messageId: "<m1@example.com>")

            let saved = try await repo.create(
                message,
                rawBlobUrl: "s3://bucket/emails/m1/raw.eml",
                attachments: [
                    EmailAttachmentInput(
                        objectStorageUrl: "s3://bucket/emails/m1/attachments/retainer.pdf",
                        filename: "retainer.pdf",
                        contentType: "application/pdf",
                        sizeBytes: 145_821,
                        contentId: nil
                    ),
                    EmailAttachmentInput(
                        objectStorageUrl: "s3://bucket/emails/m1/attachments/inline-logo.png",
                        filename: "logo.png",
                        contentType: "image/png",
                        sizeBytes: 3_128,
                        contentId: "<logo@example.com>"
                    ),
                ]
            )

            #expect(saved.id != nil)
            // $rawBlob.id is now a UUID (non-optional via @Parent); just verify the
            // blob is wired by checking it round-trips back to a real Blob row.
            let rawBlob = try await Blob.find(saved.$rawBlob.id, on: db)
            #expect(rawBlob != nil)

            let attachments = try await EmailAttachment.query(on: db)
                .filter(\.$emailMessage.$id == saved.id!)
                .sort(\.$filename, .ascending)
                .all()
            #expect(attachments.count == 2)
            #expect(attachments[0].filename == "logo.png")
            #expect(attachments[0].contentId == "<logo@example.com>")
            #expect(attachments[1].filename == "retainer.pdf")
            #expect(attachments[1].contentId == nil)

            let blobs = try await Blob.query(on: db).all()
            #expect(blobs.count == 3)
            let rawBlobs = blobs.filter { $0.referencedBy == .emailMessages }
            let attachmentBlobs = blobs.filter { $0.referencedBy == .emailAttachments }
            #expect(rawBlobs.count == 1)
            #expect(attachmentBlobs.count == 2)
            #expect(rawBlobs.first?.referencedById == saved.id)
            // referencedById is now a UUID — its mere presence as a non-zero "sentinel"
            // is no longer meaningful. Verify it points at a real EmailAttachment row.
            let attachmentIDs = attachments.compactMap { $0.id }
            #expect(attachmentBlobs.allSatisfy { attachmentIDs.contains($0.referencedById) })
        }
    }

    @Test("Duplicate message_id returns the existing row instead of inserting")
    func testCreateIsIdempotentOnMessageId() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)

            let first = try await repo.create(
                makeMessage(messageId: "<dup@example.com>"),
                rawBlobUrl: "s3://bucket/first.eml",
                attachments: []
            )

            let second = try await repo.create(
                makeMessage(messageId: "<dup@example.com>", subject: "Second try"),
                rawBlobUrl: "s3://bucket/second.eml",
                attachments: [
                    EmailAttachmentInput(
                        objectStorageUrl: "s3://bucket/file.pdf",
                        filename: "file.pdf",
                        contentType: "application/pdf",
                        sizeBytes: 1,
                        contentId: nil
                    )
                ]
            )

            #expect(second.id == first.id)
            #expect(second.subject == "Initial")

            let messageCount = try await EmailMessage.query(on: db).count()
            #expect(messageCount == 1)

            let attachmentCount = try await EmailAttachment.query(on: db).count()
            #expect(attachmentCount == 0)

            let blobCount = try await Blob.query(on: db).count()
            #expect(blobCount == 1)
        }
    }

    @Test("findByThreadId returns all messages on the thread, oldest first")
    func testFindByThreadIdOrdersByReceivedAt() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)
            let base = Date(timeIntervalSince1970: 1_712_000_000)

            let root = makeMessage(messageId: "<root@example.com>")
            root.threadId = "<root@example.com>"
            root.receivedAt = base
            _ = try await repo.create(root, rawBlobUrl: "s3://root", attachments: [])

            let reply1 = makeMessage(messageId: "<reply-1@example.com>")
            reply1.threadId = "<root@example.com>"
            reply1.receivedAt = base.addingTimeInterval(60)
            _ = try await repo.create(reply1, rawBlobUrl: "s3://r1", attachments: [])

            let reply2 = makeMessage(messageId: "<reply-2@example.com>")
            reply2.threadId = "<root@example.com>"
            reply2.receivedAt = base.addingTimeInterval(120)
            _ = try await repo.create(reply2, rawBlobUrl: "s3://r2", attachments: [])

            let thread = try await repo.findByThreadId("<root@example.com>")
            #expect(
                thread.map(\.messageId) == [
                    "<root@example.com>",
                    "<reply-1@example.com>",
                    "<reply-2@example.com>",
                ]
            )
        }
    }

    @Test("listInbox returns newest-first and paginates by received_at cursor")
    func testListInboxPaginates() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)
            let base = Date(timeIntervalSince1970: 1_712_000_000)

            for offset in 0..<5 {
                let message = makeMessage(
                    messageId: "<msg-\(offset)@example.com>",
                    toAddress: "support@neonlaw.org"
                )
                message.receivedAt = base.addingTimeInterval(TimeInterval(offset * 60))
                _ = try await repo.create(message, rawBlobUrl: "s3://m\(offset)", attachments: [])
            }

            let otherBrand = makeMessage(
                messageId: "<other@example.com>",
                toAddress: "support@sagebrush.services"
            )
            otherBrand.receivedAt = base.addingTimeInterval(10_000)
            _ = try await repo.create(otherBrand, rawBlobUrl: "s3://other", attachments: [])

            let firstPage = try await repo.listInbox(
                toAddress: "support@neonlaw.org",
                limit: 2,
                cursor: nil
            )
            #expect(
                firstPage.map(\.messageId) == [
                    "<msg-4@example.com>",
                    "<msg-3@example.com>",
                ]
            )

            let secondPage = try await repo.listInbox(
                toAddress: "support@neonlaw.org",
                limit: 2,
                cursor: firstPage.last?.receivedAt
            )
            #expect(
                secondPage.map(\.messageId) == [
                    "<msg-2@example.com>",
                    "<msg-1@example.com>",
                ]
            )
        }
    }

    @Test("countUnread counts only unacknowledged messages for the given mailbox")
    func testCountUnreadExcludesAcknowledged() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)

            let unread1 = makeMessage(messageId: "<u1@example.com>")
            let unread2 = makeMessage(messageId: "<u2@example.com>")
            let read = makeMessage(messageId: "<r1@example.com>")
            read.acknowledgedAt = Date()
            let otherBrand = makeMessage(
                messageId: "<other@example.com>",
                toAddress: "support@sagebrush.services"
            )

            _ = try await repo.create(unread1, rawBlobUrl: "s3://u1", attachments: [])
            _ = try await repo.create(unread2, rawBlobUrl: "s3://u2", attachments: [])
            _ = try await repo.create(read, rawBlobUrl: "s3://r1", attachments: [])
            _ = try await repo.create(otherBrand, rawBlobUrl: "s3://o1", attachments: [])

            let unreadCount = try await repo.countUnread(toAddress: "support@neonlaw.org")
            #expect(unreadCount == 2)
        }
    }

    @Test("Thread resolver + repository — a reply joins the seeded thread end-to-end")
    func testThreadResolverIntegrationWithRepository() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)
            let resolver = EmailThreadResolver(database: db)

            let root = makeMessage(messageId: "<root@example.com>")
            root.threadId = try await resolver.resolveThreadId(
                messageId: "<root@example.com>",
                inReplyTo: nil,
                references: []
            )
            _ = try await repo.create(root, rawBlobUrl: "s3://root", attachments: [])

            let replyThreadId = try await resolver.resolveThreadId(
                messageId: "<reply@example.com>",
                inReplyTo: "<root@example.com>",
                references: ["<root@example.com>"]
            )
            let reply = makeMessage(messageId: "<reply@example.com>")
            reply.threadId = replyThreadId
            _ = try await repo.create(reply, rawBlobUrl: "s3://reply", attachments: [])

            let thread = try await repo.findByThreadId("<root@example.com>")
            #expect(thread.count == 2)
            #expect(thread.allSatisfy { $0.threadId == "<root@example.com>" })
        }
    }

    @Test("JSON reference arrays round-trip through the model")
    func testReferencesArrayRoundTrip() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)
            let message = makeMessage(messageId: "<arrays@example.com>")
            message.references = [
                "<a@example.com>",
                "<b@example.com>",
                "<c@example.com>",
            ]
            message.ccAddresses = ["cc1@example.com", "cc2@example.com"]

            let saved = try await repo.create(message, rawBlobUrl: "s3://arr", attachments: [])

            let reloaded = try #require(try await EmailMessage.find(saved.id, on: db))
            #expect(
                reloaded.references == [
                    "<a@example.com>",
                    "<b@example.com>",
                    "<c@example.com>",
                ]
            )
            #expect(reloaded.ccAddresses == ["cc1@example.com", "cc2@example.com"])
            #expect(reloaded.bccAddresses == [])
        }
    }

    // MARK: - Helpers

    private func makeMessage(
        messageId: String,
        toAddress: String = "support@neonlaw.org",
        subject: String = "Initial"
    ) -> EmailMessage {
        let message = EmailMessage()
        message.messageId = messageId
        message.threadId = messageId
        message.fromAddress = "client@example.com"
        message.fromName = "Jane Client"
        message.toAddress = toAddress
        message.subject = subject
        message.textBody = "body"
        message.spamVerdict = "PASS"
        message.virusVerdict = "PASS"
        message.dkimVerdict = "PASS"
        message.dmarcVerdict = "PASS"
        message.receivedAt = Date()
        return message
    }
}
