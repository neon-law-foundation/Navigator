import FluentKit
import Foundation
import NavigatorDAL
import NavigatorWeb
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Reply from inbox", .serialized)
struct AdminInboxReplyTests {

    /// Builds an inbound `EmailMessage` row for the tests below to reply
    /// to. Returns the saved message.
    private func seedInbound(
        on db: Database,
        subject: String,
        fromAddress: String = "client@example.com"
    ) async throws -> EmailMessage {
        let blob = Blob()
        blob.objectStorageUrl = "s3://test/raw.eml"
        blob.referencedBy = .emailMessages
        blob.referencedById = UUID()
        try await blob.save(on: db)
        let m = EmailMessage()
        m.messageId = "<inbound-\(UUID().uuidString)@example.com>"
        m.threadId = m.messageId
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

    @Test("inbox show renders a Reply button linking to the compose form")
    func inboxShowHasReplyButton() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let parent = try await seedInbound(on: db, subject: "Help please")
            try await app.testing().test(
                .GET,
                "/admin/inbox/\(parent.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(
                        body.contains(
                            #"href="/admin/messages/new?reply_to=\#(parent.id!.uuidString)""#
                        )
                    )
                    #expect(body.contains(">Reply<"))
                }
            )
        }
    }

    @Test("compose pre-fills to, subject, and reply context from ?reply_to=…")
    func composePreFilledFromReplyTo() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let parent = try await seedInbound(on: db, subject: "Help please")
            try await app.testing().test(
                .GET,
                "/admin/messages/new?reply_to=\(parent.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Reply<"))
                    #expect(body.contains(#"value="client@example.com""#))
                    #expect(body.contains(#"value="Re: Help please""#))
                    #expect(body.contains(#"name="inReplyTo""#))
                    #expect(body.contains(#"name="parentThreadId""#))
                    #expect(body.contains(#"value="\#(parent.messageId)""#))
                }
            )
        }
    }

    @Test("subject keeps its existing Re: prefix instead of stacking another")
    func subjectKeepsExistingPrefix() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let parent = try await seedInbound(on: db, subject: "Re: Already prefixed")
            try await app.testing().test(
                .GET,
                "/admin/messages/new?reply_to=\(parent.id!.uuidString)",
                afterResponse: { res async in
                    #expect(res.body.string.contains(#"value="Re: Already prefixed""#))
                    #expect(!res.body.string.contains(#"value="Re: Re: Already prefixed""#))
                }
            )
        }
    }

    @Test("POST with inReplyTo threads the outbound row into the parent conversation")
    func sendingReplyThreadsConversation() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let parent = try await seedInbound(on: db, subject: "Help please")
            try await app.testing().test(
                .POST,
                "/admin/messages",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "to": "client@example.com",
                            "subject": "Re: Help please",
                            "body": "We are looking into it.",
                            "inReplyTo": parent.messageId,
                            "parentThreadId": parent.threadId,
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/messages/") == true)
                }
            )
            let reply = try await EmailMessage.query(on: db)
                .filter(\.$inReplyTo == parent.messageId)
                .first()
            #expect(reply != nil)
            #expect(reply?.threadId == parent.threadId)
            #expect(reply?.toAddress == "client@example.com")
            #expect(reply?.direction == .outbound)
        }
    }
}
