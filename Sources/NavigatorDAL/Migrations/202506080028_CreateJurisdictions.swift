import FluentKit

struct CreateJurisdictions: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Jurisdiction.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("name", .string, .required)
            .field("code", .string, .required)
            .field("jurisdiction_type", .string, .required)
            .field("inserted_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "code")
            .create()

    }

    func revert(on database: any Database) async throws {
        try await database.schema(Jurisdiction.schema).delete()
    }
}
