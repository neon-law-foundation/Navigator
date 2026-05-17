import FluentKit
import Foundation
import NavigatorDAL

enum IngestionResult: Sendable {
    case created(EmailMessage)
    case duplicate(EmailMessage)
}

struct EmailIngestionService: Sendable {
    let database: Database

    func ingest(
        _ request: Components.Schemas.InboundEmailRequest
    ) async throws -> IngestionResult {
        let repo = EmailMessageRepository(database: database)

        if let existing = try await repo.findByMessageId(request.messageId) {
            return .duplicate(existing)
        }

        let resolver = EmailThreadResolver(database: database)
        let threadId = try await resolver.resolveThreadId(
            messageId: request.messageId,
            inReplyTo: request.inReplyTo,
            references: request.references ?? []
        )

        let message = EmailMessage()
        message.messageId = request.messageId
        message.inReplyTo = request.inReplyTo
        message.references = JSONStored(request.references ?? [])
        message.threadId = threadId
        message.fromAddress = request.fromAddress
        message.fromName = request.fromName
        message.toAddress = request.toAddress
        message.ccAddresses = JSONStored(request.ccAddresses ?? [])
        message.bccAddresses = JSONStored(request.bccAddresses ?? [])
        message.subject = request.subject
        message.textBody = request.textBody
        message.htmlBody = request.htmlBody
        message.spamVerdict = request.spamVerdict
        message.virusVerdict = request.virusVerdict
        message.dkimVerdict = request.dkimVerdict
        message.dmarcVerdict = request.dmarcVerdict
        message.receivedAt = request.receivedAt

        let rawBlobUrl = "s3://\(request.rawBucket)/\(request.rawS3Key)"

        let attachmentInputs = (request.attachments ?? []).map { att in
            EmailAttachmentInput(
                objectStorageUrl: "s3://\(att.s3Bucket)/\(att.s3Key)",
                filename: att.filename,
                contentType: att.contentType,
                sizeBytes: att.sizeBytes,
                contentId: att.contentId
            )
        }

        let created = try await repo.create(
            message,
            rawBlobUrl: rawBlobUrl,
            attachments: attachmentInputs
        )
        return .created(created)
    }
}
