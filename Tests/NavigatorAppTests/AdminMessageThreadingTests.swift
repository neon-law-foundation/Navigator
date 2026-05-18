import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Helpers + assertions for the thread view + Forward action that span
/// both `/admin/inbox/:id` and `/admin/messages/:id`.
@Suite("Admin: Message threading + forward", .serialized)
struct AdminMessageThreadingTests {

    private func seedInbound(
        on db: Database,
        subject: String,
        fromAddress: String = "client@example.com",
        threadId: String? = nil
    ) async throws -> EmailMessage {
        let blob = Blob()
        blob.objectStorageUrl = "s3://test/raw.eml"
        blob.referencedBy = .emailMessages
        blob.referencedById = UUID()
        try await blob.save(on: db)
        let messageID = "<inbound-\(UUID().uuidString)@example.com>"
        let m = EmailMessage()
        m.messageId = messageID
        m.threadId = threadId ?? messageID
        m.fromAddress = fromAddress
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

    @Test("inbox show renders the Thread section even when alone")
    func inboxShowRendersThreadSection() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let m = try await seedInbound(on: db, subject: "Solo message")
            try await app.testing().test(
                .GET,
                "/admin/inbox/\(m.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Thread<"))
                    #expect(body.contains("No other messages in this conversation."))
                }
            )
        }
    }

    @Test("inbox show lists the inbound + outbound conversation in order")
    func inboxShowListsConversation() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let parent = try await seedInbound(on: db, subject: "Original")
            // The outbound reply inherits the inbound's thread_id.
            _ = try await EmailMessageRepository(database: db).createOutbound(
                to: parent.fromAddress,
                from: "support@neonlaw.org",
                subject: "Re: Original",
                textBody: "Replying.",
                inReplyTo: parent.messageId,
                parentThreadId: parent.threadId
            )
            try await app.testing().test(
                .GET,
                "/admin/inbox/\(parent.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-direction="inbound""#))
                    #expect(body.contains(#"data-direction="outbound""#))
                    // The current row is the parent — marker on it.
                    #expect(body.contains(#"data-current="true""#))
                }
            )
        }
    }

    @Test("inbox show renders a Forward link to the compose form")
    func inboxShowHasForwardLink() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let m = try await seedInbound(on: db, subject: "To be forwarded")
            try await app.testing().test(
                .GET,
                "/admin/inbox/\(m.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Forward<"))
                    #expect(
                        body.contains(
                            #"href="/admin/messages/new?forward=\#(m.id!.uuidString)""#
                        )
                    )
                }
            )
        }
    }

    @Test("forward compose pre-fills subject and quoted body, leaves to blank")
    func forwardComposePrefills() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let m = try await seedInbound(on: db, subject: "Quarterly review")
            m.textBody = "Hello, please review the attached."
            try await m.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/messages/new?forward=\(m.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"value="Fwd: Quarterly review""#))
                    #expect(body.contains("--- Forwarded message ---"))
                    #expect(body.contains("&gt; Hello, please review the attached."))
                    // A forward starts a new thread, so no hidden reply
                    // context inputs should render.
                    #expect(!body.contains(#"name="inReplyTo""#))
                }
            )
        }
    }

    @Test("forwarded subject already prefixed Fwd: passes through untouched")
    func forwardSubjectIdempotent() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let m = try await seedInbound(on: db, subject: "Fwd: Already a forward")
            try await app.testing().test(
                .GET,
                "/admin/messages/new?forward=\(m.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"value="Fwd: Already a forward""#))
                    #expect(!body.contains(#"value="Fwd: Fwd: Already a forward""#))
                }
            )
        }
    }

    @Test("outbound show renders the Thread section + Reply for an inbound parent")
    func outboundShowReplyTarget() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let parent = try await seedInbound(on: db, subject: "Question")
            let outbound = try await EmailMessageRepository(database: db).createOutbound(
                to: parent.fromAddress,
                from: "support@neonlaw.org",
                subject: "Re: Question",
                textBody: "Answer.",
                inReplyTo: parent.messageId,
                parentThreadId: parent.threadId
            )
            try await app.testing().test(
                .GET,
                "/admin/messages/\(outbound.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Thread<"))
                    #expect(body.contains(">Reply<"))
                    #expect(
                        body.contains(
                            #"href="/admin/messages/new?reply_to=\#(parent.id!.uuidString)""#
                        )
                    )
                }
            )
        }
    }

    @Test("outbound show without an inbound parent omits the Reply button")
    func outboundShowNoReplyButtonWhenNoParent() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let outbound = try await EmailMessageRepository(database: db).createOutbound(
                to: "fresh@example.com",
                from: "support@neonlaw.org",
                subject: "Cold outreach",
                textBody: "Hi."
            )
            try await app.testing().test(
                .GET,
                "/admin/messages/\(outbound.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    // Thread section still renders.
                    #expect(body.contains(">Thread<"))
                    // No inbound parent → no Reply affordance.
                    #expect(!body.contains(">Reply<"))
                }
            )
        }
    }
}
