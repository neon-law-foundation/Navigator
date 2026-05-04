import FluentKit

struct CreateRelationshipLogs: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(RelationshipLog.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("project_id", .uuid, .references("projects", "id"), .required)
            .field("credential_id", .uuid, .references("credentials", "id"), .required)
            .field("body", .string, .required)
            .field("relationships", .dictionary, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(RelationshipLog.schema).delete()
    }
}
