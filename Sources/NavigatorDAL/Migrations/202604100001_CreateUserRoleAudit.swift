import FluentKit
import SQLKit

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

        if database is SQLDatabase {
            try await (database as! SQLDatabase).raw(
                """
                CREATE INDEX user_role_audit_user_id_inserted_at
                ON user_role_audit (user_id, inserted_at)
                """
            ).run()
        }
    }

    func revert(on database: any Database) async throws {
        if database is SQLDatabase {
            try await (database as! SQLDatabase).raw(
                "DROP INDEX IF EXISTS user_role_audit_user_id_inserted_at"
            ).run()
        }
        try await database.schema(UserRoleAudit.schema).delete()
    }
}
