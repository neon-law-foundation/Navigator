import FluentKit
import SQLKit

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
/// The `provider` column is pinned to the enum set via a Postgres CHECK
/// constraint, mirroring the pattern used in
/// ``AddInvoicePdfsToBlobCheck``. SQLite (used in the default test harness)
/// does not support `ALTER TABLE ... ADD CONSTRAINT ... CHECK`, so the
/// constraint is Postgres-only.
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

        guard let sql = database as? SQLDatabase else { return }
        guard sql.dialect.name == "postgresql" else { return }
        try await sql.raw(
            """
            ALTER TABLE entity_billing_profiles
            ADD CONSTRAINT entity_billing_profiles_provider_check
            CHECK (provider IN ('xero'))
            """
        ).run()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(EntityBillingProfile.schema).delete()
    }
}
