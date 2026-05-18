import FluentKit
import Foundation
import Testing

@testable import NavigatorDAL

@Suite("EmailMessageRepository.createOutbound", .serialized)
struct EmailMessageOutboundTests {

    @Test("persists an outbound row with sentinel verdicts and a backing blob")
    func createsOutboundRow() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)
            let saved = try await repo.createOutbound(
                to: "client@example.com",
                from: "support@neonlaw.org",
                subject: "Hello",
                textBody: "Body."
            )
            #expect(saved.fromAddress == "support@neonlaw.org")
            #expect(saved.toAddress == "client@example.com")
            #expect(saved.spamVerdict == EmailMessage.outboundVerdictSentinel)
            #expect(saved.virusVerdict == EmailMessage.outboundVerdictSentinel)
            #expect(saved.dkimVerdict == EmailMessage.outboundVerdictSentinel)
            #expect(saved.dmarcVerdict == EmailMessage.outboundVerdictSentinel)
            #expect(saved.direction == .outbound)
            let blob = try await Blob.query(on: db)
                .filter(\.$referencedById == saved.id!)
                .filter(\.$referencedBy == .emailMessages)
                .first()
            #expect(blob != nil)
            #expect(blob?.objectStorageUrl.hasPrefix("internal:outbound/") == true)
        }
    }

    @Test("each outbound row gets a unique message id")
    func messageIdsUnique() async throws {
        try await withDatabase { db in
            let repo = EmailMessageRepository(database: db)
            let a = try await repo.createOutbound(
                to: "a@example.com",
                from: "support@neonlaw.org",
                subject: "A",
                textBody: "A"
            )
            let b = try await repo.createOutbound(
                to: "b@example.com",
                from: "support@neonlaw.org",
                subject: "B",
                textBody: "B"
            )
            #expect(a.messageId != b.messageId)
        }
    }
}
