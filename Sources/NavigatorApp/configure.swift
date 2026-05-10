import Vapor

/// Configures the Vapor application: port binding, file middleware, and routes.
public func configure(_ app: Application) async throws {
    let port = Environment.get("PORT").flatMap(Int.init) ?? 3001
    app.http.server.configuration.port = port
    app.http.server.configuration.hostname = "127.0.0.1"

    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let posts = try BlogLoader.loadAll()
    app.storage[BlogStorageKey.self] = posts

    let materials = try WorkshopMaterialsLoader.loadAll(
        publicDirectory: app.directory.publicDirectory
    )
    app.storage[WorkshopMaterialsStorageKey.self] = materials

    try routes(app)
}

/// Storage key for the parsed list of blog posts.
struct BlogStorageKey: StorageKey {
    typealias Value = [BlogPost]
}

/// Storage key for the in-memory workshop materials catalogue.
struct WorkshopMaterialsStorageKey: StorageKey {
    typealias Value = [WorkshopMaterial]
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
}
