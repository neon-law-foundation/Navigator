import FluentKit

struct CreateMailrooms: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("mailrooms")
            .field("id", .uuid, .identifier(auto: false))
            .field("name", .string, .required)
            .field("mailbox_start", .int, .required)
            .field("mailbox_end", .int, .required)
            .field("capacity", .int)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "name")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("mailrooms").delete()
    }
}
