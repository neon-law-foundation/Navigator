import FluentKit

/// Creates the `entity_billing_profiles` table, which links a Navigator
/// ``Entity`` to a billing provider's contact record (e.g. a Xero contact
/// UUID). One entity may have zero or one profile per provider.
///
/// The table is a Navigator-owned link row, not a mirror, so it carries only
/// Navigator-managed `inserted_at`/`updated_at` timestamps — no `external_*`
/// timestamps.
///
/// Unique constraints:
///
/// - `(provider, external_contact_id)` prevents duplicate mirrors of the
///   same provider-side contact.
/// - `(entity_id, provider)` enforces one profile per entity per provider.
///
/// `provider` values are validated in the Swift `EntityBillingProfile` model
/// rather than via an engine-specific `CHECK` constraint.
struct CreateEntityBillingProfiles: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(EntityBillingProfile.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("entity_id", .uuid, .references("entities", "id"), .required)
            .field("provider", .string, .required)
            .field("external_contact_id", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "provider", "external_contact_id")
            .unique(on: "entity_id", "provider")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(EntityBillingProfile.schema).delete()
    }
}
