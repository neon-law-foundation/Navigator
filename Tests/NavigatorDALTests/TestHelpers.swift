import Configuration
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import NavigatorDAL
import NavigatorDatabaseService
import Vapor

/// Executes a test with a properly configured and shutdown Application.
///
/// Selects the same database driver `NavigatorApp` selects at boot: when
/// `APP_ENV=production` and `DATABASE_URL` are set the suite runs against
/// Postgres; otherwise SQLite in-memory. Every Application is shut down
/// even when the test throws.
///
/// Postgres-mode runs share one physical database, so this helper takes
/// the process-wide `DatabaseTestSerializer` lock and runs `autoRevert()`
/// between tests to guarantee the same per-test isolation SQLite
/// in-memory provides for free. SQLite-mode runs skip the lock — each
/// call already gets a fresh in-memory database.
func withApplication<T>(
    _ operation: (Application) async throws -> T
) async throws -> T {
    let reader = ConfigReader(provider: EnvironmentVariablesProvider())
    let appEnv = reader.string(forKey: "app.env", default: "development")
    let databaseURL = reader.string(forKey: "database.url", isSecret: true)
    let usePostgres =
        appEnv == "production" && (databaseURL.map { !$0.isEmpty } ?? false)

    if usePostgres {
        await DatabaseTestSerializer.shared.acquire()
    }
    do {
        let result = try await runApplication(
            usePostgres: usePostgres,
            databaseURL: databaseURL,
            operation: operation
        )
        if usePostgres {
            await DatabaseTestSerializer.shared.release()
        }
        return result
    } catch {
        if usePostgres {
            await DatabaseTestSerializer.shared.release()
        }
        throw error
    }
}

private func runApplication<T>(
    usePostgres: Bool,
    databaseURL: String?,
    operation: (Application) async throws -> T
) async throws -> T {
    let app = try await Application.make(.testing)
    if usePostgres, let databaseURL {
        let config = try SQLPostgresConfiguration(url: databaseURL)
        app.databases.use(.postgres(configuration: config), as: .psql)
    } else {
        app.databases.use(.sqlite(.memory), as: .sqlite)
    }
    for migration in NavigatorDALConfiguration.migrations {
        app.migrations.add(migration)
    }
    try await app.autoMigrate()

    do {
        let result = try await operation(app)
        if usePostgres {
            try await app.autoRevert()
        }
        try await app.asyncShutdown()
        return result
    } catch {
        if usePostgres {
            try? await app.autoRevert()
        }
        try await app.asyncShutdown()
        throw error
    }
}

/// Executes a test with a properly configured Application and database access.
///
/// Convenience wrapper that passes the database directly.
func withDatabase<T>(
    _ operation: (Database) async throws -> T
) async throws -> T {
    try await withApplication { app in
        try await operation(app.db)
    }
}
