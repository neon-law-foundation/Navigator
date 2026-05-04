import FluentKit
import Foundation

/// Represents a blob reference stored in object storage (AWS S3) or local filesystem in development and testing.
///
/// **Polymorphism Pattern:**
/// This model uses polymorphism to allow a single blob storage table to be referenced
/// by multiple different entity types. The `referencedBy` field acts as a discriminator
/// that identifies which type of entity is referencing the blob, while `referencedById`
/// contains the UUID of that specific entity.
///
/// This pattern enables:
/// - A single blob storage table that can serve multiple entity types
/// - Consistent blob management across the application
/// - Easier maintenance of file storage logic
/// - Referential integrity through foreign key constraints
public final class Blob: Model, @unchecked Sendable {
    public static let schema = "blobs"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "object_storage_url")
    public var objectStorageUrl: String

    /// Polymorphic discriminator indicating which type of entity references this blob
    @Field(key: "referenced_by")
    public var referencedBy: BlobReferencedBy

    /// UUID of the specific entity that references this blob (polymorphic foreign key).
    ///
    /// Polymorphic foreign keys cannot have a database-level `REFERENCES` constraint
    /// because the target table varies by `referencedBy` discriminator; integrity is
    /// enforced at the application layer instead.
    @Field(key: "referenced_by_id")
    public var referencedById: UUID

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}

public enum BlobReferencedBy: String, Codable, CaseIterable, Sendable {
    // Referenced by a letter in the mail.letters table (scanned_document_id field)
    case letters = "letters"

    // Referenced by a share issuance in the equity.share_issuances table (document_id field)
    case shareIssuances = "share_issuances"

    // Referenced by an answer in the matters.answers table (blob_id field)
    case answers = "answers"

    // Referenced by a document in the matters.documents table (blob_id field)
    case documents = "documents"

    // Referenced by an email message in the mail.email_messages table (raw_blob_id field)
    // — stores the raw MIME source of a received email.
    case emailMessages = "email_messages"

    // Referenced by an email attachment in the mail.email_attachments table (blob_id field)
    // — stores the decoded bytes of one attachment part on a received email.
    case emailAttachments = "email_attachments"

    // Referenced by an invoice in the invoices table (pdf_blob_id field)
    // — stores the Xero-rendered invoice PDF uploaded to S3 by the Reporting sync Lambda.
    case invoicePdfs = "invoice_pdfs"
}
