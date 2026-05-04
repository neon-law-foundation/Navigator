import FluentKit

/// Creates the `addresses` table.
///
/// An address belongs to either a ``Person`` or an ``Entity`` (XOR — enforced by
/// service-layer code). The optional `mailroom_id` foreign key marks an address
/// as a managed mailbox handled by a physical ``Mailroom``.
struct CreateAddresses: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Address.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("entity_id", .uuid, .references("entities", "id"))
            .field("person_id", .uuid, .references("people", "id"))
            .field("mailroom_id", .uuid, .references("mailrooms", "id"))
            .field("street", .string, .required)
            .field("city", .string, .required)
            .field("state", .string)
            .field("zip", .string)
            .field("country", .string, .required)
            .field("is_verified", .bool, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Address.schema).delete()
    }
}
