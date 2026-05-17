import Configuration
import NavigatorDatabaseService

/// Builds a `DatabaseService` for the test suite using the same
/// configuration path `NavigatorApp` uses at boot.
///
/// When `APP_ENV=production` and `DATABASE_URL` are set the service
/// connects to Postgres; otherwise it falls back to SQLite in-memory.
/// Migrations run before the service is returned so the caller can
/// immediately make queries against it.
///
/// Postgres-mode callers must wrap their setup-and-test block in
/// ``withDatabaseTestLock(_:)`` so concurrent tests do not stomp on the
/// shared physical database.
func makeTestDatabaseService() async throws -> DatabaseService {
    let service = try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:")
    try await service.migrate()
    return service
}

/// Acquires the process-wide Postgres-test mutex when the suite runs in
/// Postgres mode and runs `operation` while holding it. SQLite-mode runs
/// invoke `operation` immediately because every test already gets its
/// own in-memory database.
func withDatabaseTestLock<T>(
    _ operation: () async throws -> T
) async throws -> T {
    if isUsingPostgresMode() {
        await DatabaseTestSerializer.shared.acquire()
        do {
            let result = try await operation()
            await DatabaseTestSerializer.shared.release()
            return result
        } catch {
            await DatabaseTestSerializer.shared.release()
            throw error
        }
    }
    return try await operation()
}

/// `true` when `APP_ENV=production` and `DATABASE_URL` is set — the
/// configuration that routes the suite to Postgres. Exposed so each
/// database-touching suite can opt out in Postgres mode via
/// `.disabled(if: isUsingPostgresMode(), ...)`. The DAL suite covers the
/// Postgres path; Web tests construct their own `DatabaseService` per
/// test without holding the shared serializer and can race the
/// migrate-phase CREATE TABLE on the `_fluent_migrations` catalog.
@Sendable
func isUsingPostgresMode() -> Bool {
    let reader = ConfigReader(provider: EnvironmentVariablesProvider())
    let appEnv = reader.string(forKey: "app.env", default: "development")
    let databaseURL = reader.string(forKey: "database.url", isSecret: true)
    return appEnv == "production" && (databaseURL.map { !$0.isEmpty } ?? false)
}
