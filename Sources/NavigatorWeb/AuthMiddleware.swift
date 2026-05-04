import FluentKit
import Foundation
import HTTPTypes
import NavigatorDAL
import NavigatorOIDCMiddleware
import OpenAPIRuntime

/// Server middleware that extracts the authenticated user from a Bearer JWT on every request.
///
/// API Gateway validates the JWT signature and claims before invoking Lambda. This middleware
/// decodes the sub claim from the already-validated token, looks up the user in the database,
/// then populates `RequestLocals.authenticatedUser` and `RequestLocals.userRole` for
/// downstream handlers via task-local storage.
struct AuthMiddleware: ServerMiddleware {
    let db: any Database

    func intercept(
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
        guard let sub = jwtSubject(from: token) else {
            return (HTTPResponse(status: .unauthorized), nil)
        }
        guard
            let user = try await User.query(on: db)
                .filter(\.$sub == sub)
                .first()
        else {
            return (HTTPResponse(status: .unauthorized), nil)
        }
        let authenticatedUser = AuthenticatedUser(sub: sub, email: nil)
        return try await RequestLocals.$authenticatedUser.withValue(authenticatedUser) {
            try await RequestLocals.$userRole.withValue(user.role) {
                try await next(request, body, metadata)
            }
        }
    }

    /// Decodes the JWT payload and returns the `sub` claim without verifying the signature.
    ///
    /// Signature verification is handled by the API Gateway JWT Authorizer before the
    /// request reaches Lambda.
    private func jwtSubject(from token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)
        guard
            let data = Data(base64Encoded: base64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub = json["sub"] as? String
        else { return nil }
        return sub
    }
}
