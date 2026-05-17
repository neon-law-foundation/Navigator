import Configuration

extension DatabaseService {
    /// Builds a `DatabaseService` whose driver is selected by environment
    /// variables read through `swift-configuration`.
    ///
    /// - `APP_ENV == production` plus a non-empty `DATABASE_URL`: Postgres.
    /// - Anything else: SQLite at `NAVIGATOR_DB_PATH`, or in-memory when
    ///   that value is `:memory:`. `NAVIGATOR_DB_PATH` falls back to
    ///   `defaultSQLitePath` when unset — production callers want a stable
    ///   file (`navigator.sqlite`); test callers want `:memory:`.
    ///
    /// - Parameters:
    ///   - defaultSQLitePath: Fallback used when `NAVIGATOR_DB_PATH` is
    ///     not set. Production sets this to `navigator.sqlite`; tests set
    ///     it to `:memory:`.
    ///   - reader: Inject a custom `ConfigReader` for testing. Production
    ///     callers should accept the default, which reads the process's
    ///     environment variables.
    /// - Throws: ``DatabaseService/EnvironmentConfigurationError/missingDatabaseURL``
    ///   when `APP_ENV == production` is set without a `DATABASE_URL`.
    public static func fromEnvironment(
        defaultSQLitePath: String = "navigator.sqlite",
        reader: ConfigReader = ConfigReader(provider: EnvironmentVariablesProvider())
    ) throws -> DatabaseService {
        let appEnv = reader.string(forKey: "app.env", default: "development")
        let databaseURL = reader.string(forKey: "database.url", isSecret: true)
        let navigatorDBPath = reader.string(
            forKey: "navigator.db.path",
            default: defaultSQLitePath
        )

        if appEnv == "production" {
            guard let databaseURL, !databaseURL.isEmpty else {
                throw EnvironmentConfigurationError.missingDatabaseURL
            }
            return try DatabaseService(databaseURL: databaseURL)
        }
        if navigatorDBPath == ":memory:" {
            return DatabaseService(configuration: .memory)
        }
        return DatabaseService(configuration: .file(navigatorDBPath))
    }

    /// Errors raised when ``DatabaseService/fromEnvironment(defaultSQLitePath:reader:)``
    /// cannot resolve a complete configuration.
    public enum EnvironmentConfigurationError: Error, CustomStringConvertible, Sendable {
        /// `APP_ENV` is `production` but `DATABASE_URL` is unset or empty.
        case missingDatabaseURL

        public var description: String {
            switch self {
            case .missingDatabaseURL:
                return
                    "APP_ENV=production requires DATABASE_URL to be set to a Postgres connection URL."
            }
        }
    }
}

/// Process-wide async mutex shared across every test target that touches
/// the database.
///
/// Swift Testing runs tests cooperatively in parallel within a single
/// test binary. In SQLite in-memory mode that is fine — each test owns
/// its own database. In Postgres mode every connection points at the
/// same physical database, so test helpers acquire this lock for the
/// duration of one test's migrate / work / revert cycle. SQLite-mode
/// callers can skip the lock entirely.
public actor DatabaseTestSerializer {
    public static let shared = DatabaseTestSerializer()

    private var inUse = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func acquire() async {
        if !inUse {
            inUse = true
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
    }

    public func release() {
        if waiters.isEmpty {
            inUse = false
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}
