import Fluent
import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import Testing
import Vapor

/// Runtime invariants on timestamp columns.
///
/// The `inserted_at` / `updated_at` column naming convention is enforced at
/// the migration site (see `@Timestamp(key: "inserted_at", on: .create)` on
/// every model). A schema-introspection sweep would require engine-specific
/// catalog queries (`PRAGMA table_info` on SQLite, `information_schema` on
/// Postgres) which violate the "no engine-specific SQL" rule, so the static
/// rule is only verified by code review and by the model definitions.
@Suite("Timestamp invariants")
struct TimestampInvariantTests {
    @Test("On a freshly inserted record, inserted_at equals updated_at")
    func freshInsertHasEqualTimestamps() async throws {
        try await withDatabase { db in
            let person = Person()
            person.name = "Timestamp Test"
            person.email = "timestamp-test@example.com"
            try await person.save(on: db)

            let inserted = try #require(person.insertedAt)
            let updated = try #require(person.updatedAt)
            #expect(
                inserted == updated,
                "On first save, inserted_at and updated_at must match — Fluent sets both via @Timestamp"
            )
        }
    }
}
