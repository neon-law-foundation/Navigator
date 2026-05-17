import FluentKit

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
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Retainer.schema).delete()
    }
}
