import FluentKit
import Foundation

/// Represents a physical piece of mail managed by a `Mailroom`.
///
/// A `Letter` tracks an item of physical mail received at a mailroom, optionally
/// associating a scanned document blob with the record once the item has been processed.
public final class Letter: Model, @unchecked Sendable {
    public static let schema = "letters"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "mailroom_id")
    public var mailroom: Mailroom

    @OptionalParent(key: "scanned_document_id")
    public var scannedDocument: Blob?

    @OptionalField(key: "sender")
    public var sender: String?

    @OptionalField(key: "subject")
    public var subject: String?

    @OptionalField(key: "received_at")
    public var receivedAt: Date?

    @OptionalField(key: "mailbox_number")
    public var mailboxNumber: Int?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
