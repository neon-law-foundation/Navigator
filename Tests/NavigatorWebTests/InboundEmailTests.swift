import Crypto
import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorOIDCMiddleware
import Testing

@testable import NavigatorWeb

@Suite("Inbound Email Ingestion", .serialized)
struct InboundEmailTests {
    private let secret = "test-ingest-secret"

    private func makeHandler(dbService: DatabaseService) async throws -> APIHandler {
        let db = try await dbService.db
        return APIHandler(
            db: db,
            databaseService: dbService,
            emailService: EmailService(),
            storageService: StorageService(bucketURL: ""),
            authMiddleware: AuthMiddleware(db: db),
            mailIngestSecret: secret
        )
    }

    private func signRequest(
        _ request: Components.Schemas.InboundEmailRequest
    ) throws -> String {
        let data = try HMACVerifier.encoder.encode(request)
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return "sha256=" + Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    private func makeRequest(
        messageId: String = "<20260410.abc@example.com>",
        inReplyTo: String? = nil,
        references: [String]? = nil,
        fromAddress: String = "client@example.com",
        fromName: String? = "Jane Client",
        toAddress: String = "support@neonlaw.org",
        subject: String = "Question about your workshop",
        textBody: String? = "Hello, I have a question.",
        htmlBody: String? = "<p>Hello, I have a question.</p>",
        attachments: [Components.Schemas.InboundEmailAttachment]? = nil
    ) -> Components.Schemas.InboundEmailRequest {
        Components.Schemas.InboundEmailRequest(
            messageId: messageId,
            inReplyTo: inReplyTo,
            references: references,
            fromAddress: fromAddress,
            fromName: fromName,
            toAddress: toAddress,
            ccAddresses: nil,
            bccAddresses: nil,
            subject: subject,
            textBody: textBody,
            htmlBody: htmlBody,
            rawS3Key: "emails/2026/04/10/\(messageId)/raw.eml",
            rawBucket: "nlf-inbound-mail-prod",
            spamVerdict: "PASS",
            virusVerdict: "PASS",
            dkimVerdict: "PASS",
            dmarcVerdict: "PASS",
            receivedAt: Date(),
            attachments: attachments
        )
    }

    // MARK: - HMAC Auth

    @Test("Missing signature returns 401")
    func missingSignatureReturns401() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let handler = try await makeHandler(dbService: dbService)
        let request = makeRequest()
        let input = Operations.ingestInboundEmail.Input(
            headers: .init(X_hyphen_NLF_hyphen_Signature: ""),
            body: .json(request)
        )
        let output = try await handler.ingestInboundEmail(input)
        if case .undocumented(let statusCode, _) = output {
            #expect(statusCode == 401)
        } else {
            Issue.record("Expected 401 for missing signature")
        }
        await dbService.shutdown()
    }

    @Test("Wrong signature returns 401")
    func wrongSignatureReturns401() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let handler = try await makeHandler(dbService: dbService)
        let request = makeRequest()
        let input = Operations.ingestInboundEmail.Input(
            headers: .init(X_hyphen_NLF_hyphen_Signature: "sha256=deadbeef"),
            body: .json(request)
        )
        let output = try await handler.ingestInboundEmail(input)
        if case .undocumented(let statusCode, _) = output {
            #expect(statusCode == 401)
        } else {
            Issue.record("Expected 401 for wrong signature")
        }
        await dbService.shutdown()
    }

    // MARK: - Successful Ingestion

    @Test("Valid request creates email and returns 200")
    func validRequestCreatesEmail() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let handler = try await makeHandler(dbService: dbService)
        let request = makeRequest()
        let signature = try signRequest(request)
        let input = Operations.ingestInboundEmail.Input(
            headers: .init(X_hyphen_NLF_hyphen_Signature: signature),
            body: .json(request)
        )
        let output = try await handler.ingestInboundEmail(input)
        switch output {
        case .ok(let response):
            switch response.body {
            case .json(let email):
                #expect(email.messageId == "<20260410.abc@example.com>")
                #expect(email.threadId == "<20260410.abc@example.com>")
            }
        default:
            Issue.record("Expected 200 ok, got \(output)")
        }

        let db = try await dbService.db
        let repo = EmailMessageRepository(database: db)
        let stored = try await repo.findByMessageId("<20260410.abc@example.com>")
        #expect(stored != nil)
        #expect(stored?.subject == "Question about your workshop")
        #expect(stored?.fromAddress == "client@example.com")
        #expect(stored?.toAddress == "support@neonlaw.org")
        await dbService.shutdown()
    }

    // MARK: - Idempotency (409)

    @Test("Duplicate message_id returns 409 with existing record")
    func duplicateReturns409() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let handler = try await makeHandler(dbService: dbService)
        let request = makeRequest(messageId: "<dup@example.com>")
        let signature = try signRequest(request)
        let input = Operations.ingestInboundEmail.Input(
            headers: .init(X_hyphen_NLF_hyphen_Signature: signature),
            body: .json(request)
        )

        let firstOutput = try await handler.ingestInboundEmail(input)
        guard case .ok = firstOutput else {
            Issue.record("First ingestion should succeed")
            await dbService.shutdown()
            return
        }

        let secondOutput = try await handler.ingestInboundEmail(input)
        switch secondOutput {
        case .conflict(let response):
            switch response.body {
            case .json(let email):
                #expect(email.messageId == "<dup@example.com>")
            }
        default:
            Issue.record("Expected 409 conflict on duplicate, got \(secondOutput)")
        }
        await dbService.shutdown()
    }

    // MARK: - Threading

    @Test("Reply correctly joins parent thread")
    func replyJoinsThread() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let handler = try await makeHandler(dbService: dbService)

        let parentRequest = makeRequest(
            messageId: "<parent@example.com>",
            subject: "Original message"
        )
        let parentInput = Operations.ingestInboundEmail.Input(
            headers: .init(X_hyphen_NLF_hyphen_Signature: try signRequest(parentRequest)),
            body: .json(parentRequest)
        )
        let parentOutput = try await handler.ingestInboundEmail(parentInput)
        guard case .ok = parentOutput else {
            Issue.record("Parent ingestion should succeed")
            await dbService.shutdown()
            return
        }

        let replyRequest = makeRequest(
            messageId: "<reply@example.com>",
            inReplyTo: "<parent@example.com>",
            references: ["<parent@example.com>"],
            subject: "Re: Original message"
        )
        let replyInput = Operations.ingestInboundEmail.Input(
            headers: .init(X_hyphen_NLF_hyphen_Signature: try signRequest(replyRequest)),
            body: .json(replyRequest)
        )
        let replyOutput = try await handler.ingestInboundEmail(replyInput)
        switch replyOutput {
        case .ok(let response):
            switch response.body {
            case .json(let email):
                #expect(email.threadId == "<parent@example.com>")
            }
        default:
            Issue.record("Reply ingestion should succeed with parent's threadId")
        }
        await dbService.shutdown()
    }

    @Test("Orphan reply starts a new thread")
    func orphanReplyStartsNewThread() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let handler = try await makeHandler(dbService: dbService)

        let orphanRequest = makeRequest(
            messageId: "<orphan@example.com>",
            inReplyTo: "<unknown@example.com>",
            subject: "Re: Something old"
        )
        let orphanInput = Operations.ingestInboundEmail.Input(
            headers: .init(X_hyphen_NLF_hyphen_Signature: try signRequest(orphanRequest)),
            body: .json(orphanRequest)
        )
        let orphanOutput = try await handler.ingestInboundEmail(orphanInput)
        switch orphanOutput {
        case .ok(let response):
            switch response.body {
            case .json(let email):
                #expect(email.threadId == "<orphan@example.com>")
            }
        default:
            Issue.record("Orphan should start its own thread")
        }
        await dbService.shutdown()
    }

    // MARK: - Attachments

    @Test("Email with attachments persists attachment records")
    func emailWithAttachments() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let handler = try await makeHandler(dbService: dbService)

        let attachment = Components.Schemas.InboundEmailAttachment(
            filename: "signed-retainer.pdf",
            contentType: "application/pdf",
            sizeBytes: 145_821,
            contentId: nil,
            s3Key: "emails/2026/04/10/attachments/signed-retainer.pdf",
            s3Bucket: "nlf-inbound-mail-prod"
        )
        let request = makeRequest(
            messageId: "<attach@example.com>",
            attachments: [attachment]
        )
        let signature = try signRequest(request)
        let input = Operations.ingestInboundEmail.Input(
            headers: .init(X_hyphen_NLF_hyphen_Signature: signature),
            body: .json(request)
        )
        let output = try await handler.ingestInboundEmail(input)
        guard case .ok = output else {
            Issue.record("Expected 200 ok")
            await dbService.shutdown()
            return
        }

        let db = try await dbService.db
        let attachments = try await EmailAttachment.query(on: db).all()
        #expect(attachments.count == 1)
        #expect(attachments.first?.filename == "signed-retainer.pdf")
        #expect(attachments.first?.contentType == "application/pdf")
        #expect(attachments.first?.sizeBytes == 145_821)
        await dbService.shutdown()
    }
}
