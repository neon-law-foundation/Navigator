import FluentKit
import SQLKit

/// Creates the `invoice_line_items` table, the child rows of an ``Invoice``.
///
/// The `invoice_id` foreign key is declared with `onDelete: .cascade` so that
/// deleting a parent invoice cleans up its line items in the same statement —
/// there is no soft-delete or orphan-line-item state in this mirror.
///
/// Line items are reconciled by **full replacement**, never per-row merge:
/// ``InvoiceLineItemRepository/replaceAll(forInvoiceId:with:)`` deletes the
/// existing set for an invoice and re-inserts the supplied payloads inside a
/// single transaction. There is deliberately no UNIQUE constraint on
/// `external_line_item_id` — the column is captured for traceability back to
/// Xero, but it is not trusted as a per-row identity for merging.
///
/// Monetary columns use `.custom(SQLRaw("NUMERIC(19,4)"))` so both Postgres
/// and SQLite carry exact numeric storage (Postgres respects the precision;
/// SQLite resolves the type via affinity).
struct CreateInvoiceLineItems: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(InvoiceLineItem.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field(
                "invoice_id",
                .uuid,
                .references("invoices", "id", onDelete: .cascade),
                .required
            )
            .field("line_number", .int32, .required)
            .field("external_line_item_id", .string)
            .field("description", .string, .required)
            .field("item_code", .string)
            .field("account_code", .string)
            .field("quantity", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("unit_amount", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("tax_type", .string)
            .field("tax_amount", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("line_amount", .custom(SQLRaw("NUMERIC(19,4)")), .required)
            .field("discount_rate", .custom(SQLRaw("NUMERIC(19,4)")))
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(InvoiceLineItem.schema).delete()
    }
}
