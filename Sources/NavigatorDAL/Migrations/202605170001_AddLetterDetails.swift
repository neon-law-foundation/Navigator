import FluentKit

/// Adds `sender`, `subject`, `received_at`, and `mailbox_number` to the
/// `letters` table.
///
/// Each column is added in its own `update()` because SQLite's
/// `ALTER TABLE ... ADD COLUMN` rejects multiple column definitions in
/// one statement (Fluent's `.update()` emits a single statement). The
/// columns are nullable so an `ADD COLUMN` against rows from earlier
/// schema versions does not require a default.
struct AddLetterDetails: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Letter.schema)
            .field("sender", .string)
            .update()
        try await database.schema(Letter.schema)
            .field("subject", .string)
            .update()
        try await database.schema(Letter.schema)
            .field("received_at", .datetime)
            .update()
        try await database.schema(Letter.schema)
            .field("mailbox_number", .int)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Letter.schema)
            .deleteField("sender")
            .update()
        try await database.schema(Letter.schema)
            .deleteField("subject")
            .update()
        try await database.schema(Letter.schema)
            .deleteField("received_at")
            .update()
        try await database.schema(Letter.schema)
            .deleteField("mailbox_number")
            .update()
    }
}
