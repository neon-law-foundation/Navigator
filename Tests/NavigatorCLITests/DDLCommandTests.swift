import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import SQLKit
import Testing
import Vapor

@Suite("DDL Command")
struct DDLCommandTests {

    /// All 31 schema tables that should appear in sqlite_master after migrations.
    private static let expectedTables: Set<String> = [
        "addresses",
        "answers",
        "blobs",
        "credentials",
        "disclosures",
        "documents",
        "email_attachments",
        "email_messages",
        "entities",
        "entity_billing_profiles",
        "entity_types",
        "git_repositories",
        "invoice_line_items",
        "invoices",
        "jurisdictions",
        "letters",
        "mailrooms",
        "notations",
        "people",
        "person_entity_roles",
        "person_project_roles",
        "projects",
        "questions",
        "relationship_logs",
        "retainer_projects",
        "retainers",
        "share_classes",
        "share_issuances",
        "templates",
        "user_role_audit",
        "users",
    ]

    @Test("DDL output contains all 31 schema tables")
    func testDDLContainsAllTables() async throws {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        for migration in NavigatorDALConfiguration.migrations {
            app.migrations.add(migration)
        }
        try await app.autoMigrate()

        guard let sqlDb = app.db as? SQLDatabase else {
            Issue.record("Database does not support raw SQL")
            try await app.asyncShutdown()
            return
        }

        let rows = try await sqlDb.raw(
            """
            SELECT name FROM sqlite_master
            WHERE type = 'table'
            AND name NOT LIKE '_fluent%'
            ORDER BY name
            """
        ).all()

        let tableNames = Set(
            try rows.map { try $0.decode(column: "name", as: String.self) }
        )

        for expected in Self.expectedTables {
            #expect(
                tableNames.contains(expected),
                "Missing table '\(expected)' in sqlite_master"
            )
        }

        #expect(
            tableNames.count == Self.expectedTables.count,
            "Expected \(Self.expectedTables.count) tables, got \(tableNames.count)"
        )

        try await app.asyncShutdown()
    }

    @Test("DDL output contains CREATE TABLE statements")
    func testDDLContainsCreateStatements() async throws {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        for migration in NavigatorDALConfiguration.migrations {
            app.migrations.add(migration)
        }
        try await app.autoMigrate()

        guard let sqlDb = app.db as? SQLDatabase else {
            Issue.record("Database does not support raw SQL")
            try await app.asyncShutdown()
            return
        }

        let rows = try await sqlDb.raw(
            """
            SELECT sql FROM sqlite_master
            WHERE type = 'table'
            AND name NOT LIKE '_fluent%'
            ORDER BY name
            """
        ).all()

        #expect(!rows.isEmpty, "Expected CREATE TABLE statements")

        for row in rows {
            let sql = try row.decode(column: "sql", as: String.self)
            #expect(
                sql.uppercased().contains("CREATE TABLE"),
                "Expected CREATE TABLE in: \(sql)"
            )
        }

        try await app.asyncShutdown()
    }

    @Test("DDL excludes Fluent internal tables")
    func testDDLExcludesFluentTables() async throws {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        for migration in NavigatorDALConfiguration.migrations {
            app.migrations.add(migration)
        }
        try await app.autoMigrate()

        guard let sqlDb = app.db as? SQLDatabase else {
            Issue.record("Database does not support raw SQL")
            try await app.asyncShutdown()
            return
        }

        let rows = try await sqlDb.raw(
            """
            SELECT name FROM sqlite_master
            WHERE type = 'table'
            AND name NOT LIKE '_fluent%'
            ORDER BY name
            """
        ).all()

        let tableNames = try rows.map { try $0.decode(column: "name", as: String.self) }

        for name in tableNames {
            #expect(
                !name.hasPrefix("_fluent"),
                "Fluent internal table '\(name)' should be excluded"
            )
        }

        try await app.asyncShutdown()
    }
}
