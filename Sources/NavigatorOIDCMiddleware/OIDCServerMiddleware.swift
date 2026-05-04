import FluentKit
import HTTPTypes
import JWTKit
import NavigatorDAL
import OpenAPIRuntime

/// Task-local storage for the authenticated user and their role, set by ``OIDCServerMiddleware``.
public enum RequestLocals {
    @TaskLocal public static var authenticatedUser: AuthenticatedUser? = nil
    @TaskLocal public static var userRole: UserRole? = nil
}

/// OpenAPI Runtime server middleware that validates a Bearer JWT and resolves the subject
/// to a database user, storing both in task-local storage for downstream handlers.
///
/// Validates the token signature, issuer, and audience claims, then looks up the user
/// via ``UserRepository/findBySub(_:)``. Sets ``RequestLocals/authenticatedUser`` and
/// ``RequestLocals/userRole`` for the duration of the request.
///
/// Returns `401 Unauthorized` when:
/// - The `Authorization: Bearer <token>` header is missing
/// - The JWT signature or claims are invalid
/// - No database user matches the token's subject
public struct OIDCServerMiddleware: ServerMiddleware {
    public let keyCollection: JWTKeyCollection
    public let issuerURL: String
    public let clientID: String
    public let database: any Database

    public init(
        keyCollection: JWTKeyCollection,
        issuerURL: String,
        clientID: String,
        database: any Database
    ) {
        self.keyCollection = keyCollection
        self.issuerURL = issuerURL
        self.clientID = clientID
        self.database = database
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        metadata: ServerRequestMetadata,
        operationID: String,
        next:
            @Sendable (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws -> (
                HTTPResponse, HTTPBody?
            )
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard
            let authHeader = request.headerFields[.authorization],
            authHeader.hasPrefix("Bearer ")
        else {
            return (HTTPResponse(status: .unauthorized), nil)
        }
        let token = String(authHeader.dropFirst("Bearer ".count))
        let payload: OIDCIDTokenPayload
        do {
            payload = try await keyCollection.verify(token, as: OIDCIDTokenPayload.self)
        } catch {
            return (HTTPResponse(status: .unauthorized), nil)
        }
        guard payload.iss.value == issuerURL, payload.aud.value.contains(clientID) else {
            return (HTTPResponse(status: .unauthorized), nil)
        }
        let authenticatedUser = AuthenticatedUser(sub: payload.sub.value, email: payload.email)
        let repo = UserRepository(database: database)
        guard let user = try await repo.findBySub(authenticatedUser.sub) else {
            return (HTTPResponse(status: .unauthorized), nil)
        }
        return try await RequestLocals.$authenticatedUser.withValue(authenticatedUser) {
            try await RequestLocals.$userRole.withValue(user.role) {
                try await next(request, body, metadata)
            }
        }
    }
}
