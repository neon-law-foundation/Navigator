import FluentKit

struct CreateShareClasses: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ShareClass.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("name", .string, .required)
            .field("entity_id", .uuid, .references("entities", "id"), .required)
            .field("priority", .int, .required)
            .field("description", .string)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "entity_id", "priority")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ShareClass.schema).delete()
    }
}
