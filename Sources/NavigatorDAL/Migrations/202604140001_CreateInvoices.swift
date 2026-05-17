import FluentKit
import SQLKit

/// Creates the `invoices` table, a one-way mirror of an upstream billing
/// provider's invoice header (initially Xero).
///
/// The table is keyed for upsert idempotency by
/// `UNIQUE (billing_profile_id, external_invoice_id)` — the
/// ``InvoiceRepository`` reconciliation logic skips business-field writes
/// when `external_updated_at` is unchanged, using `synced_at` to record the
/// reconciliation attempt in every case.
///
/// There is deliberately no `external_created_at` column: Xero's invoice
/// payload exposes only `UpdatedDateUTC`. If a future provider exposes a
/// creation timestamp, add the column then rather than leaving an empty
/// field Navigator cannot fill.
///
/// Monetary columns are declared via `.custom(SQLRaw("NUMERIC(19,4)"))` so
/// that Postgres stores them as exact numeric values with no precision loss.
/// SQLite resolves `NUMERIC(19,4)` via type affinity and accepts the same
/// declaration without further configuration.
///
/// The string-typed enums (`status`, `invoice_type`, `currency_code`) are
/// validated by the Swift `Invoice` model rather than by per-engine `CHECK`
/// constraints, so the schema is identical on SQLite and Postgres.
struct CreateInvoices: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Invoice.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field(
                "billing_profile_id",
                .uuid,
                .references("entity_billing_profiles", "id"),
                .required
            )
            .field("external_invoice_id", .string, .required)
            .field("invoice_number", .string)
            .field("reference", .string)
            .field("status", .string, .required)
            .field("invoice_type", .string, .required)
            .field("currency_code", .string, .required)
            .field("invoice_date", .date, .required)
            .field("due_date", .date)
            .field("sub_total", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("total_tax", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("total", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("amount_due", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("amount_paid", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("amount_credited", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("pdf_blob_id", .uuid, .references("blobs", "id"))
            .field("external_updated_at", .datetime, .required)
            .field("synced_at", .datetime, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "billing_profile_id", "external_invoice_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Invoice.schema).delete()
    }
}
