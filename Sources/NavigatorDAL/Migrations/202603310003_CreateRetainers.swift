import FluentKit
import SQLKit

struct CreateRetainers: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Retainer.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("clients", .json, .required)
            .field("notation_id", .uuid, .references("notations", "id"), .required)
            .field("status", .string, .required)
            .field("starts_at", .datetime)
            .field("ends_at", .datetime)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()

        guard let sql = database as? SQLDatabase else { return }
        let isPostgres = sql.dialect.name == "postgresql"
        guard isPostgres else { return }
        try await sql.raw(
            "CREATE INDEX retainers_clients_gin ON retainers USING GIN (clients jsonb_path_ops)"
        ).run()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Retainer.schema).delete()
    }
}
