import FluentKit
import SQLKit

/// Creates the `blobs` table — polymorphic storage for binary content referenced
/// by other tables (letters, share issuances, answers, documents, raw email MIME,
/// email attachments, and Xero-rendered invoice PDFs).
///
/// `referenced_by` acts as a discriminator that pairs with `referenced_by_id` to
/// identify the owning row. The CHECK constraint enumerates every valid value of
/// ``BlobReferencedBy`` so a typo in application code surfaces immediately on
/// insert. The constraint is Postgres-only — SQLite (used in tests) does not
/// enforce CHECK constraints reliably.
struct CreateBlobs: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Blob.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("object_storage_url", .string, .required)
            .field("referenced_by", .string, .required)
            .field("referenced_by_id", .uuid, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "object_storage_url")
            .create()

        guard let sql = database as? SQLDatabase else { return }
        guard sql.dialect.name == "postgresql" else { return }
        try await sql.raw(
            """
            ALTER TABLE blobs ADD CONSTRAINT blobs_referenced_by_check
            CHECK (referenced_by IN (
                'letters',
                'share_issuances',
                'answers',
                'documents',
                'email_messages',
                'email_attachments',
                'invoice_pdfs'
            ))
            """
        ).run()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Blob.schema).delete()
    }
}
