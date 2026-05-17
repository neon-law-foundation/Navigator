import Configuration
import NavigatorDatabaseService

/// Resolved runtime configuration for `NavigatorApp`.
///
/// Every environment variable the app honors flows through this type:
///
/// - `APP_ENV` — `production`, `development`, or `test`. Defaults to
///   `development` when unset.
/// - `DATABASE_URL` — required when `APP_ENV == production`. A Postgres
///   connection URL such as `postgres://user:pass@host:5432/db`.
/// - `NAVIGATOR_DB_PATH` — SQLite path used outside production. Defaults
///   to `navigator.sqlite`; pass `:memory:` for an ephemeral in-memory
///   database.
/// - `PORT` — TCP port the HTTP server binds. Defaults to `3001`.
///
/// All reads go through `swift-configuration`'s `ConfigReader`. Nothing in
/// `NavigatorApp` is allowed to touch `ProcessInfo` or Vapor's
/// `Environment.get` directly.
public struct AppConfiguration: Sendable {
    /// Discrete deployment environments the app understands. The string
    /// raw values match the values an operator would set in `APP_ENV`.
    public enum AppEnv: String, Sendable {
        case development
        case production
        case test
    }

    public let appEnv: AppEnv
    public let port: Int
    public let sqliteDefaultPath: String

    public init(
        appEnv: AppEnv,
        port: Int,
        sqliteDefaultPath: String = "navigator.sqlite"
    ) {
        self.appEnv = appEnv
        self.port = port
        self.sqliteDefaultPath = sqliteDefaultPath
    }

    /// Builds an `AppConfiguration` from the process environment.
    ///
    /// - Parameters:
    ///   - sqliteDefaultPath: SQLite filename to fall back on when
    ///     `NAVIGATOR_DB_PATH` is not set. Production runs accept the
    ///     default (`navigator.sqlite`); the test harness overrides this
    ///     to `:memory:` so each test boots an isolated in-memory database.
    ///   - reader: Override the reader for testing. Production callers
    ///     should accept the default, which reads the current process's
    ///     environment variables.
    public static func fromEnvironment(
        sqliteDefaultPath: String = "navigator.sqlite",
        reader: ConfigReader = ConfigReader(provider: EnvironmentVariablesProvider())
    ) -> AppConfiguration {
        let appEnv = reader.string(forKey: "app.env", as: AppEnv.self, default: .development)
        let port = reader.int(forKey: "port", default: 3001)
        return AppConfiguration(
            appEnv: appEnv,
            port: port,
            sqliteDefaultPath: sqliteDefaultPath
        )
    }

    /// Constructs the `DatabaseService` this configuration selects.
    ///
    /// Delegates to ``NavigatorDatabaseService/DatabaseService/fromEnvironment(defaultSQLitePath:reader:)``,
    /// which reads `DATABASE_URL` / `NAVIGATOR_DB_PATH` through the same
    /// configuration pipeline. The factory throws when `APP_ENV` is
    /// `production` but `DATABASE_URL` is missing.
    public func makeDatabaseService() throws -> DatabaseService {
        try DatabaseService.fromEnvironment(defaultSQLitePath: sqliteDefaultPath)
    }
}
