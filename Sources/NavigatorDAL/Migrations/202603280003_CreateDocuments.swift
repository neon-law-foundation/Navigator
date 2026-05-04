import FluentKit

struct CreateDocuments: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Document.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("project_id", .uuid, .references("projects", "id"), .required)
            .field("blob_id", .uuid, .references("blobs", "id"), .required)
            .field("title", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Document.schema).delete()
    }
}
