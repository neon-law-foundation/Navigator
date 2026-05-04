import FluentKit

struct CreateDisclosures: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Disclosure.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("credential_id", .uuid, .references("credentials", "id"), .required)
            .field("project_id", .uuid, .references("projects", "id"), .required)
            .field("disclosed_at", .datetime, .required)
            .field("end_disclosed_at", .datetime)
            .field("active", .bool, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Disclosure.schema).delete()
    }
}
