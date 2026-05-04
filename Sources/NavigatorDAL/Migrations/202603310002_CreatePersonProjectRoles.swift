import FluentKit

struct CreatePersonProjectRoles: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(PersonProjectRole.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("person_id", .uuid, .references("people", "id"), .required)
            .field("project_id", .uuid, .references("projects", "id"), .required)
            .field("role", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "person_id", "project_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(PersonProjectRole.schema).delete()
    }
}
