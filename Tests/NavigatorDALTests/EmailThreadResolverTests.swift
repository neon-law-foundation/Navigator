import Fluent
import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import Testing
import Vapor

@Suite(
    "EmailThreadResolver",
    .disabled(
        if: isUsingPostgresMode(),
        "Model encodes jsonb columns as text; Postgres rejects until the model is fixed."
    )
)
struct EmailThreadResolverTests {

    @Test("New message with no headers becomes its own thread root")
    func testNewThreadFromEmptyHeaders() async throws {
        try await withDatabase { db in
            let resolver = EmailThreadResolver(database: db)
            let threadId = try await resolver.resolveThreadId(
                messageId: "<root@example.com>",
                inReplyTo: nil,
                references: []
            )
            #expect(threadId == "<root@example.com>")
        }
    }

    @Test("Direct reply inherits parent thread id via In-Reply-To")
    func testDirectReplyInheritsParentThread() async throws {
        try await withDatabase { db in
            try await seedRoot(
                on: db,
                messageId: "<root@example.com>",
                threadId: "<root@example.com>"
            )

            let resolver = EmailThreadResolver(database: db)
            let threadId = try await resolver.resolveThreadId(
                messageId: "<reply@example.com>",
                inReplyTo: "<root@example.com>",
                references: []
            )
            #expect(threadId == "<root@example.com>")
        }
    }

    @Test("Multi-hop chain walks References head-to-tail and adopts the first match")
    func testMultiHopReferencesWalk() async throws {
        try await withDatabase { db in
            try await seedRoot(
                on: db,
                messageId: "<a@example.com>",
                threadId: "<a@example.com>"
            )

            let resolver = EmailThreadResolver(database: db)
            let threadId = try await resolver.resolveThreadId(
                messageId: "<d@example.com>",
                inReplyTo: "<c@example.com>",
                references: ["<a@example.com>", "<b@example.com>", "<c@example.com>"]
            )
            #expect(threadId == "<a@example.com>")
        }
    }

    @Test("References walk picks the earliest match when multiple ancestors are known")
    func testReferencesWalkPrefersOldestMatch() async throws {
        try await withDatabase { db in
            try await seedRoot(
                on: db,
                messageId: "<a@example.com>",
                threadId: "<a@example.com>"
            )
            try await seedRoot(
                on: db,
                messageId: "<c@example.com>",
                threadId: "<different-thread@example.com>"
            )

            let resolver = EmailThreadResolver(database: db)
            let threadId = try await resolver.resolveThreadId(
                messageId: "<d@example.com>",
                inReplyTo: nil,
                references: ["<a@example.com>", "<b@example.com>", "<c@example.com>"]
            )
            #expect(threadId == "<a@example.com>")
        }
    }

    @Test("Orphan reply — unknown parent and unknown ancestors — starts a new thread")
    func testOrphanReplyStartsNewThread() async throws {
        try await withDatabase { db in
            let resolver = EmailThreadResolver(database: db)
            let threadId = try await resolver.resolveThreadId(
                messageId: "<orphan@example.com>",
                inReplyTo: "<missing-parent@example.com>",
                references: ["<missing-gp@example.com>"]
            )
            #expect(threadId == "<orphan@example.com>")
        }
    }

    @Test("Self-reply from support@ preserves the original thread id")
    func testSelfReplyPreservesThread() async throws {
        try await withDatabase { db in
            try await seedRoot(
                on: db,
                messageId: "<client-1@example.com>",
                threadId: "<client-1@example.com>",
                toAddress: "support@neonlaw.org",
                fromAddress: "client@example.com"
            )

            let resolver = EmailThreadResolver(database: db)
            let threadId = try await resolver.resolveThreadId(
                messageId: "<support-reply-1@neonlaw.org>",
                inReplyTo: "<client-1@example.com>",
                references: ["<client-1@example.com>"]
            )
            #expect(threadId == "<client-1@example.com>")
        }
    }

    @Test("In-Reply-To match wins over References walk when both resolve to different threads")
    func testInReplyToWinsOverReferences() async throws {
        try await withDatabase { db in
            try await seedRoot(
                on: db,
                messageId: "<old-thread@example.com>",
                threadId: "<old-thread@example.com>"
            )
            try await seedRoot(
                on: db,
                messageId: "<direct-parent@example.com>",
                threadId: "<direct-parent@example.com>"
            )

            let resolver = EmailThreadResolver(database: db)
            let threadId = try await resolver.resolveThreadId(
                messageId: "<forward@example.com>",
                inReplyTo: "<direct-parent@example.com>",
                references: ["<old-thread@example.com>"]
            )
            #expect(threadId == "<direct-parent@example.com>")
        }
    }

    // MARK: - Helpers

    private func seedRoot(
        on db: Database,
        messageId: String,
        threadId: String,
        toAddress: String = "support@neonlaw.org",
        fromAddress: String = "client@example.com"
    ) async throws {
        let blob = Blob()
        blob.objectStorageUrl = "s3://seed/\(messageId)"
        blob.referencedBy = .emailMessages
        blob.referencedById = UUID()
        try await blob.save(on: db)

        let message = EmailMessage()
        message.messageId = messageId
        message.threadId = threadId
        message.fromAddress = fromAddress
        message.toAddress = toAddress
        message.subject = "Seed"
        message.$rawBlob.id = blob.id!
        message.spamVerdict = "PASS"
        message.virusVerdict = "PASS"
        message.dkimVerdict = "PASS"
        message.dmarcVerdict = "PASS"
        message.receivedAt = Date()
        try await message.save(on: db)
    }
}
