import FluentKit

struct CreateEntityTypes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(EntityType.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("name", .string, .required)
            .field("jurisdiction_id", .uuid, .references("jurisdictions", "id"), .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "name", "jurisdiction_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(EntityType.schema).delete()
    }
}
