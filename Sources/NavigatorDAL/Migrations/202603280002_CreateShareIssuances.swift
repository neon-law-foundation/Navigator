import FluentKit

struct CreateShareIssuances: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ShareIssuance.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("entity_id", .uuid, .references("entities", "id"), .required)
            .field("shareholder_type", .string, .required)
            .field("shareholder_id", .uuid, .required)
            .field("document_id", .uuid, .references("blobs", "id"))
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ShareIssuance.schema).delete()
    }
}
