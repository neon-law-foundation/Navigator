import Configuration
import NavigatorDatabaseService

/// Runs `operation` against a freshly-migrated ``DatabaseService`` and tears
/// the service down before returning.
///
/// In Postgres mode the call is serialized on ``DatabaseTestSerializer/shared``
/// and the schema is reverted both before and after `operation` so each test
/// runs against the same clean slate it would get from an SQLite in-memory
/// database. SQLite-mode runs skip the lock and the reverts because every
/// service already owns its own ephemeral database.
///
/// `shutdown()` is awaited on every exit path — including thrown errors — so
/// the underlying Postgres connection pool reaches `deinit` only after it has
/// drained. Bypassing this helper risks the
/// `ConnectionPool.shutdown() was not called before deinit` debug assertion
/// at process exit.
func withTestDatabaseService<T>(
    _ operation: (DatabaseService) async throws -> T
) async throws -> T {
    let usePostgres = isUsingPostgres()
    if usePostgres {
        await DatabaseTestSerializer.shared.acquire()
    }
    let outcome: Result<T, Error>
    do {
        outcome = .success(try await runOnce(usePostgres: usePostgres, operation: operation))
    } catch {
        outcome = .failure(error)
    }
    if usePostgres {
        await DatabaseTestSerializer.shared.release()
    }
    return try outcome.get()
}

private func runOnce<T>(
    usePostgres: Bool,
    operation: (DatabaseService) async throws -> T
) async throws -> T {
    let service = try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:")
    do {
        if usePostgres {
            try? await service.revert()
        }
        try await service.migrate()
        let value = try await operation(service)
        if usePostgres {
            try? await service.revert()
        }
        await service.shutdown()
        return value
    } catch {
        if usePostgres {
            try? await service.revert()
        }
        await service.shutdown()
        throw error
    }
}

private func isUsingPostgres() -> Bool {
    let reader = ConfigReader(provider: EnvironmentVariablesProvider())
    let appEnv = reader.string(forKey: "app.env", default: "development")
    let databaseURL = reader.string(forKey: "database.url", isSecret: true)
    return appEnv == "production" && (databaseURL.map { !$0.isEmpty } ?? false)
}
