import FluentKit

/// Creates the `blobs` table — polymorphic storage for binary content referenced
/// by other tables (letters, share issuances, answers, documents, raw email MIME,
/// email attachments, and Xero-rendered invoice PDFs).
///
/// `referenced_by` acts as a discriminator that pairs with `referenced_by_id` to
/// identify the owning row. Valid values are enumerated by ``BlobReferencedBy``
/// and validated in the Swift layer; the schema itself is portable across
/// SQLite and Postgres.
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
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Blob.schema).delete()
    }
}
