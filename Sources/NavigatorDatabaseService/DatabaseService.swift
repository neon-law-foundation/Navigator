import Fluent
import FluentKit
import FluentPostgresDriver
import FluentSQLiteDriver
import Logging
import NIOCore
import NIOPosix
import NavigatorDAL

/// Manages the application database connection and runs `NavigatorDAL` migrations.
///
/// Provides two initializers:
/// - Production: connects to Postgres via a `DATABASE_URL` connection string.
/// - Local / test: connects to an SQLite database (file-based or in-memory).
public actor DatabaseService {
    private let databases: Databases
    private let databaseID: DatabaseID

    /// The active database connection.
    ///
    /// - Throws: `DatabaseError.notConfigured` if the database was shut down before this is called.
    public var db: any Database {
        get throws {
            guard
                let database = databases.database(
                    databaseID,
                    logger: Logger(label: "db"),
                    on: MultiThreadedEventLoopGroup.singleton.any()
                )
            else {
                throw DatabaseError.notConfigured
            }
            return database
        }
    }

    /// Creates a production database service connecting to Postgres via a connection URL.
    ///
    /// - Parameter databaseURL: A full Postgres connection URL (e.g.
    ///   `postgres://user:password@host:5432/dbname`). Typically read from the `DATABASE_URL`
    ///   environment variable.
    public init(databaseURL: String) throws {
        let databases = Databases(
            threadPool: NIOThreadPool.singleton,
            on: MultiThreadedEventLoopGroup.singleton
        )
        let config = try SQLPostgresConfiguration(url: databaseURL)
        databases.use(DatabaseConfigurationFactory.postgres(configuration: config), as: .psql)
        self.databaseID = .psql
        self.databases = databases
    }

    /// Creates a local SQLite database service.
    ///
    /// - Parameter configuration: The SQLite configuration. Defaults to `.file("db.sqlite")` for
    ///   local development. Pass `.memory` in tests to keep each test suite isolated and avoid
    ///   file conflicts from parallel test runs.
    public init(configuration: SQLiteConfiguration = .file("db.sqlite")) {
        let databases = Databases(
            threadPool: NIOThreadPool.singleton,
            on: MultiThreadedEventLoopGroup.singleton
        )
        databases.use(DatabaseConfigurationFactory.sqlite(configuration), as: .sqlite)
        self.databaseID = .sqlite
        self.databases = databases
    }

    /// Runs all `NavigatorDAL` migrations and seeds.
    ///
    /// Migrations run once (Fluent tracks applied migrations). Seeds run on every call and are
    /// idempotent — existing records matched by `lookup_fields` are skipped or updated.
    public func migrate() async throws {
        let migrations = Migrations()
        migrations.add(NavigatorDALConfiguration.migrations)
        let migrator = Migrator(
            databases: databases,
            migrations: migrations,
            logger: Logger(label: "fluent.migrations"),
            on: MultiThreadedEventLoopGroup.singleton.any()
        )
        try await migrator.setupIfNeeded().get()
        try await migrator.prepareBatch().get()
        _ = try await NavigatorDALConfiguration.runSeeds(on: try db, logger: Logger(label: "fluent.seeds"))
    }

    /// Verifies the database is reachable by running an empty transaction.
    public func healthCheck() async throws -> Bool {
        try await (try db).transaction { _ in }
        return true
    }

    /// Shuts down all database connections.
    public func shutdown() {
        databases.shutdown()
    }
}

/// Errors thrown by ``DatabaseService``.
public enum DatabaseError: Error {
    case notConfigured
}
