import FluentKit
import Foundation

/// Describes one attachment to be persisted alongside an ``EmailMessage``.
///
/// The caller supplies the S3 URL the parser Lambda has already written to,
/// plus the file metadata extracted from the MIME part. The repository
/// creates the backing ``Blob`` row, sets its polymorphic discriminator, and
/// wires up the ``EmailAttachment`` row in the same transaction as the
/// parent message.
public struct EmailAttachmentInput: Sendable {

    /// The object storage URL where the decoded bytes already live.
    public let objectStorageUrl: String

    /// The filename declared in the `Content-Disposition` header.
    public let filename: String

    /// The declared MIME type — e.g. `application/pdf`.
    public let contentType: String

    /// The size of the decoded attachment in bytes.
    public let sizeBytes: Int64

    /// The `Content-ID` of inline resources referenced from the HTML body
    /// via `cid:` URIs, or `nil` for regular attachments.
    public let contentId: String?

    public init(
        objectStorageUrl: String,
        filename: String,
        contentType: String,
        sizeBytes: Int64,
        contentId: String? = nil
    ) {
        self.objectStorageUrl = objectStorageUrl
        self.filename = filename
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.contentId = contentId
    }
}

/// Persists and retrieves ``EmailMessage`` rows and their attachments.
///
/// The repository owns the transactional boundary around creating an email:
/// ``create(_:rawBlobUrl:attachments:)`` writes the raw-MIME ``Blob``, the
/// ``EmailMessage`` row, then one ``Blob`` + ``EmailAttachment`` pair per
/// attachment, all inside a single Fluent transaction.
///
/// Idempotency on `message_id` is enforced by the database unique index:
/// a duplicate ingestion returns the existing row rather than raising.
public struct EmailMessageRepository: Sendable {

    private let database: Database

    /// Creates a new `EmailMessageRepository`.
    ///
    /// - Parameter database: The Fluent database connection used for all operations.
    public init(database: Database) {
        self.database = database
    }

    /// Persists a new email and its attachments in a single transaction.
    ///
    /// The caller passes a partially-populated ``EmailMessage`` with all envelope
    /// fields set but without a `raw_blob_id` — the repository creates the raw
    /// ``Blob`` row, wires it to the message, saves the message, then creates
    /// one ``Blob`` + ``EmailAttachment`` pair for each entry in `attachments`.
    ///
    /// If an email with the same ``EmailMessage/messageId`` already exists, the
    /// existing row is returned untouched — the operation is idempotent on the
    /// wire-level `message_id`.
    ///
    /// - Parameters:
    ///   - message: The ``EmailMessage`` to persist. Its `raw_blob_id` is set
    ///     by this call; all other envelope fields must already be populated.
    ///   - rawBlobUrl: Object storage URL of the raw MIME source written by
    ///     the parser Lambda.
    ///   - attachments: One ``EmailAttachmentInput`` per decoded MIME attachment.
    /// - Returns: The saved ``EmailMessage``, or the pre-existing row on duplicate.
    public func create(
        _ message: EmailMessage,
        rawBlobUrl: String,
        attachments: [EmailAttachmentInput]
    ) async throws -> EmailMessage {
        if let existing = try await findByMessageId(message.messageId) {
            return existing
        }

        return try await database.transaction { tx in
            // Pre-allocate UUIDs for the message and each attachment so the polymorphic
            // `referenced_by_id` on each backing Blob can be set before the dependent
            // row is written. With Int32 auto-increment IDs this required a placeholder
            // value and a second UPDATE — UUID primary keys remove that round-trip.
            let messageID = UUID()
            message.id = messageID

            let rawBlob = Blob()
            rawBlob.objectStorageUrl = rawBlobUrl
            rawBlob.referencedBy = .emailMessages
            rawBlob.referencedById = messageID
            try await rawBlob.save(on: tx)

            message.$rawBlob.id = rawBlob.id!
            try await message.save(on: tx)

            for input in attachments {
                let attachmentID = UUID()

                let attachmentBlob = Blob()
                attachmentBlob.objectStorageUrl = input.objectStorageUrl
                attachmentBlob.referencedBy = .emailAttachments
                attachmentBlob.referencedById = attachmentID
                try await attachmentBlob.save(on: tx)

                let attachment = EmailAttachment()
                attachment.id = attachmentID
                attachment.$emailMessage.id = messageID
                attachment.$blob.id = attachmentBlob.id!
                attachment.filename = input.filename
                attachment.contentType = input.contentType
                attachment.sizeBytes = input.sizeBytes
                attachment.contentId = input.contentId
                try await attachment.save(on: tx)
            }

            return message
        }
    }

    /// Composes a new outbound email and persists it as an ``EmailMessage`` row.
    ///
    /// Outbound rows share the inbound schema; columns that have no
    /// meaning for sent mail are filled with sentinel values:
    /// ``EmailMessage/outboundVerdictSentinel`` for the four SES verdicts,
    /// the send timestamp for `received_at`, and an empty `references` /
    /// `cc_addresses` / `bcc_addresses` array. The raw-MIME ``Blob`` is
    /// pointed at a synthetic `internal:outbound/<message-id>` URL because
    /// the admin compose flow does not upload to S3.
    ///
    /// The new row's `from_address` is the caller-supplied address and is
    /// expected to be one of ``EmailMessage/supportFromAddresses`` — the
    /// caller validates this so the repository remains transport-neutral.
    ///
    /// - Parameters:
    ///   - to: The recipient address (`To:` header).
    ///   - from: The verified SES sender address (`From:` header).
    ///   - subject: The subject line.
    ///   - textBody: The plain-text message body.
    /// - Returns: The saved ``EmailMessage`` row.
    public func createOutbound(
        to: String,
        from: String,
        subject: String,
        textBody: String
    ) async throws -> EmailMessage {
        try await database.transaction { tx in
            let messageID = UUID()
            let messageIdHeader = "<\(messageID.uuidString)@neonlaw.org>"

            let blob = Blob()
            blob.objectStorageUrl = "internal:outbound/\(messageID.uuidString)"
            blob.referencedBy = .emailMessages
            blob.referencedById = messageID
            try await blob.save(on: tx)

            let message = EmailMessage()
            message.id = messageID
            message.messageId = messageIdHeader
            message.threadId = messageIdHeader
            message.fromAddress = from
            message.toAddress = to
            message.subject = subject
            message.textBody = textBody
            message.$rawBlob.id = blob.id!
            message.spamVerdict = EmailMessage.outboundVerdictSentinel
            message.virusVerdict = EmailMessage.outboundVerdictSentinel
            message.dkimVerdict = EmailMessage.outboundVerdictSentinel
            message.dmarcVerdict = EmailMessage.outboundVerdictSentinel
            message.receivedAt = Date()
            try await message.save(on: tx)
            return message
        }
    }

    /// Returns the email with the given RFC 5322 `Message-ID`, or `nil` if none exists.
    ///
    /// Used by ``EmailThreadResolver`` during ancestor lookups and by the
    /// ingestion endpoint to detect duplicate deliveries.
    public func findByMessageId(_ messageId: String) async throws -> EmailMessage? {
        try await EmailMessage.query(on: database)
            .filter(\.$messageId == messageId)
            .first()
    }

    /// Returns all emails belonging to a thread, oldest first.
    ///
    /// - Parameter threadId: The denormalized thread identifier.
    /// - Returns: Every message with that thread id, ordered by `received_at` ascending.
    public func findByThreadId(_ threadId: String) async throws -> [EmailMessage] {
        try await EmailMessage.query(on: database)
            .filter(\.$threadId == threadId)
            .sort(\.$receivedAt, .ascending)
            .all()
    }

    /// Returns a page of inbox messages for a given `support@<domain>` address.
    ///
    /// Messages are returned newest-first using `received_at` as the ordering key.
    /// The `cursor` parameter is a `received_at` timestamp from the previous
    /// page — only messages strictly older than the cursor are returned. Pass
    /// `nil` to fetch the first page.
    ///
    /// - Parameters:
    ///   - toAddress: The recipient mailbox, e.g. `support@neonlaw.org`.
    ///   - limit: Maximum page size. Defaults to 50.
    ///   - cursor: `received_at` timestamp from the last row of the previous
    ///     page, or `nil` for the first page.
    /// - Returns: A page of ``EmailMessage`` rows, newest first.
    public func listInbox(
        toAddress: String,
        limit: Int = 50,
        cursor: Date? = nil
    ) async throws -> [EmailMessage] {
        var query = EmailMessage.query(on: database)
            .filter(\.$toAddress == toAddress)

        if let cursor {
            query = query.filter(\.$receivedAt < cursor)
        }

        return
            try await query
            .sort(\.$receivedAt, .descending)
            .limit(limit)
            .all()
    }

    /// Returns the number of unread messages in a given inbox.
    ///
    /// An email is considered unread when its ``EmailMessage/acknowledgedAt``
    /// is `nil`. The admin UI stamps that column when an operator opens a
    /// message for the first time.
    ///
    /// - Parameter toAddress: The recipient mailbox whose unread count to return.
    /// - Returns: The number of unacknowledged messages addressed to `toAddress`.
    public func countUnread(toAddress: String) async throws -> Int {
        try await EmailMessage.query(on: database)
            .filter(\.$toAddress == toAddress)
            .filter(\.$acknowledgedAt == nil)
            .count()
    }
}
