import FluentKit

struct CreateCredentials: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Credential.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("person_id", .uuid, .references("people", "id"), .required)
            .field("jurisdiction_id", .uuid, .references("jurisdictions", "id"), .required)
            .field("license_number", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "jurisdiction_id", "license_number")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Credential.schema).delete()
    }
}
