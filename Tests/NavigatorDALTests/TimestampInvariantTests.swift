import Fluent
import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import SQLKit
import Testing
import Vapor

/// Schema-wide invariants on timestamp columns.
///
/// Every table produced by `NavigatorDALConfiguration.migrations` must:
/// - have an `inserted_at` column,
/// - have an `updated_at` column,
/// - **not** have a `created_at` column.
///
/// `inserted_at` / `updated_at` is the codebase convention — `created_at` is
/// the Fluent default we deliberately don't use, so seeing it appear means
/// someone forgot to specify the key on `@Timestamp(...)`.
@Suite("Timestamp invariants")
struct TimestampInvariantTests {

    @Test("Every table has inserted_at and updated_at and no created_at")
    func everyTableHasCorrectTimestampColumns() async throws {
        try await withApplication { app in
            guard let sql = app.db as? SQLDatabase else {
                Issue.record("Database does not support raw SQL")
                return
            }

            let tableRows = try await sql.raw(
                """
                SELECT name FROM sqlite_master
                WHERE type = 'table'
                AND name NOT LIKE '_fluent%'
                AND name != 'sqlite_sequence'
                ORDER BY name
                """
            ).all()

            let tables = try tableRows.map { try $0.decode(column: "name", as: String.self) }
            #expect(!tables.isEmpty, "Migrations should produce at least one table")

            for table in tables {
                let columnRows = try await sql.raw(
                    SQLQueryString(stringLiteral: "PRAGMA table_info(\(table))")
                ).all()
                let columns = Set(
                    try columnRows.map { try $0.decode(column: "name", as: String.self) }
                )

                #expect(columns.contains("inserted_at"), "Table '\(table)' is missing inserted_at")
                #expect(columns.contains("updated_at"), "Table '\(table)' is missing updated_at")
                #expect(
                    !columns.contains("created_at"),
                    "Table '\(table)' has forbidden created_at column — use inserted_at instead"
                )
            }
        }
    }

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
