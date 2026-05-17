import Foundation
import NavigatorDatabaseService
import OpenAPIVapor
import Vapor

/// Registers every operation declared in `openapi.yaml` on the given Vapor
/// application under `serverURL`. The default `/api` prefix matches the
/// public route layout — the JSON API lives at `/api/...` on every brand
/// hostname, served from the same process as the HTML site.
///
/// - Parameters:
///   - app: The Vapor application that will own the routes.
///   - databaseService: The shared `DatabaseService` used by every handler.
///   - serverURL: The base URL to register operations under. Pass a
///     path-only URL like `/api` to mount under a sub-prefix on the same
///     host.
///   - mailIngestSecret: HMAC secret for the inbound-email endpoint.
///     When empty the endpoint rejects every request — fail-secure default
///     for environments that have not provisioned the secret yet.
public func registerAPIRoutes(
    on app: Application,
    databaseService: DatabaseService,
    serverURL: URL,
    mailIngestSecret: String = ""
) async throws {
    let db = try await databaseService.db
    let handler = APIHandler(
        db: db,
        databaseService: databaseService,
        emailService: EmailService(),
        storageService: StorageService(bucketURL: ""),
        authMiddleware: AuthMiddleware(db: db),
        mailIngestSecret: mailIngestSecret
    )
    let transport = VaporTransport(routesBuilder: app)
    try handler.registerHandlers(on: transport, serverURL: serverURL)
}
