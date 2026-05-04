import FluentKit

struct CreateRetainerProjects: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(RetainerProject.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("retainer_id", .uuid, .references("retainers", "id"), .required)
            .field("project_id", .uuid, .references("projects", "id"), .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "retainer_id", "project_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(RetainerProject.schema).delete()
    }
}
