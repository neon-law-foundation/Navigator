import FluentKit

struct CreateLetters: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Letter.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("mailroom_id", .uuid, .references("mailrooms", "id"), .required)
            .field("scanned_document_id", .uuid, .references("blobs", "id"))
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Letter.schema).delete()
    }
}
