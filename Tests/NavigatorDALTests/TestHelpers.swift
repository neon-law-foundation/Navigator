import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Vapor

/// Executes a test with a properly configured and shutdown Application
/// This ensures the Application is always shut down, even if the test throws
func withApplication<T>(
    _ operation: (Application) async throws -> T
) async throws -> T {
    let app = try await Application.make(.testing)
    app.databases.use(.sqlite(.memory), as: .sqlite)
    for migration in NavigatorDALConfiguration.migrations {
        app.migrations.add(migration)
    }
    try await app.autoMigrate()

    do {
        let result = try await operation(app)
        try await app.asyncShutdown()
        return result
    } catch {
        try await app.asyncShutdown()
        throw error
    }
}

/// Executes a test with a properly configured Application and database access
/// Convenience wrapper that passes the database directly
func withDatabase<T>(
    _ operation: (Database) async throws -> T
) async throws -> T {
    try await withApplication { app in
        try await operation(app.db)
    }
}
