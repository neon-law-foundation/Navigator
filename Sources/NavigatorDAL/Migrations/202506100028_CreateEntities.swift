import FluentKit

struct CreateEntities: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Entity.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("name", .string, .required)
            .field("legal_entity_type_id", .uuid, .references("entity_types", "id"), .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "legal_entity_type_id", "name")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Entity.schema).delete()
    }
}
