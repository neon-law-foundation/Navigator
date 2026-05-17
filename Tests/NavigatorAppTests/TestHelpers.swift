import NavigatorDatabaseService
import Vapor

@testable import NavigatorApp

/// `withApp`-compatible configure closure that wires the application
/// through ``AppConfiguration`` with `:memory:` as the SQLite fallback.
///
/// Production-flavored runs (`APP_ENV=production` + `DATABASE_URL=...`)
/// flow through unchanged, which is what powers the Postgres CI matrix
/// job. Local and default-CI runs land on an isolated SQLite in-memory
/// database without writing files.
///
/// In Postgres mode the helper acquires the shared
/// ``DatabaseTestSerializer`` lock so configure/migrate cycles do not
/// race with other suites against the same physical database, reverts
/// any leftover schema from a prior crashed run before configure() runs
/// migrations, and reverts again at app shutdown so the next test starts
/// against an empty database. The lock releases after the revert.
@Sendable
func testConfigure(_ app: Application) async throws {
    let appConfiguration = AppConfiguration.fromEnvironment(sqliteDefaultPath: ":memory:")
    let usePostgres = appConfiguration.appEnv == .production
    if usePostgres {
        await DatabaseTestSerializer.shared.acquire()
    }
    do {
        if usePostgres {
            let cleanService = try appConfiguration.makeDatabaseService()
            try? await cleanService.revert()
            await cleanService.shutdown()
        }
        try await configure(app, appConfiguration: appConfiguration)
    } catch {
        if usePostgres {
            await DatabaseTestSerializer.shared.release()
        }
        throw error
    }
    if usePostgres {
        app.lifecycle.use(PostgresTestCleanupHandler())
    }
}

struct PostgresTestCleanupHandler: LifecycleHandler {
    func shutdownAsync(_ application: Application) async {
        try? await application.autoRevert()
        await DatabaseTestSerializer.shared.release()
    }
}
