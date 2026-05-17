import FluentKit

struct CreateUserRoleAudit: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(UserRoleAudit.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("user_id", .uuid, .references("users", "id"), .required)
            .field("changed_by_user_id", .uuid, .references("users", "id"), .required)
            .field("previous_role", .string, .required)
            .field("new_role", .string, .required)
            .field("reason", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(UserRoleAudit.schema).delete()
    }
}
