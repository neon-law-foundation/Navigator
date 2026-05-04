import FluentKit

struct CreatePersonEntityRoles: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(PersonEntityRole.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("person_id", .uuid, .references("people", "id"), .required)
            .field("entity_id", .uuid, .references("entities", "id"), .required)
            .field("role", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "person_id", "entity_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(PersonEntityRole.schema).delete()
    }
}
