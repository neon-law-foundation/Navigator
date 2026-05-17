import Foundation
import NavigatorDatabaseService
import NavigatorWeb
import Vapor

/// Configures the Vapor application using values resolved from the
/// environment. Reads `APP_ENV`, `DATABASE_URL`, `NAVIGATOR_DB_PATH`,
/// and `PORT` via `AppConfiguration` and wires the matching database
/// driver before request routing comes up.
public func configure(_ app: Application) async throws {
    let appConfiguration = AppConfiguration.fromEnvironment()
    try await configure(app, appConfiguration: appConfiguration)
}

/// Configures the Vapor application against a pre-built
/// ``AppConfiguration``. The single-argument overload is the entry point
/// production uses; tests construct their own configuration and call this
/// overload so they can pin the database driver without touching the
/// process environment.
public func configure(
    _ app: Application,
    appConfiguration: AppConfiguration
) async throws {
    app.http.server.configuration.port = appConfiguration.port
    app.http.server.configuration.hostname = "127.0.0.1"

    let databaseService = try appConfiguration.makeDatabaseService()
    // Register for shutdown BEFORE migrating so the connection pool drains
    // cleanly even if `migrate()` throws — otherwise the unreleased pool
    // hits its `deinit` assertion at process exit.
    await app.storage.setWithAsyncShutdown(
        DatabaseServiceStorageKey.self,
        to: databaseService,
        onShutdown: { service in
            await service.shutdown()
        }
    )
    try await databaseService.migrate()

    // Canonical-host redirect runs first so apex traffic never reaches
    // the rest of the middleware chain — every other middleware (file
    // serving, routing) only ever sees requests on a canonical host.
    app.middleware.use(CanonicalHostMiddleware())
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let posts = try BlogLoader.loadAll()
    app.storage[BlogStorageKey.self] = posts

    let materials = try WorkshopMaterialsLoader.loadAll(
        publicDirectory: app.directory.publicDirectory
    )
    app.storage[WorkshopMaterialsStorageKey.self] = materials

    try routes(app)

    try await registerAPIRoutes(
        on: app,
        databaseService: databaseService,
        serverURL: URL(string: "/api")!
    )
}

/// Storage key for the parsed list of blog posts.
struct BlogStorageKey: StorageKey {
    typealias Value = [BlogPost]
}

/// Storage key for the in-memory workshop materials catalogue.
struct WorkshopMaterialsStorageKey: StorageKey {
    typealias Value = [WorkshopMaterial]
}

/// Storage key for the shared database service.
struct DatabaseServiceStorageKey: StorageKey {
    typealias Value = DatabaseService
}

extension Application {
    /// All blog posts loaded at startup, sorted newest-first.
    public var blogPosts: [BlogPost] {
        storage[BlogStorageKey.self] ?? []
    }

    /// Claude Code + Twelve Zodiac Lawyers workshop materials, loaded at
    /// startup from `Public/workshops/claude-code-zodiac/`.
    public var workshopMaterials: [WorkshopMaterial] {
        storage[WorkshopMaterialsStorageKey.self] ?? []
    }

    /// Shared `DatabaseService` for the configured driver, populated by
    /// `configure(_:)` at boot. Returns `nil` before the app finishes
    /// configuration or in tests that opted out of database wiring.
    public var databaseService: DatabaseService? {
        storage[DatabaseServiceStorageKey.self]
    }
}
