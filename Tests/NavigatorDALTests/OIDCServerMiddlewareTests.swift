import Fluent
import FluentSQLiteDriver
import HTTPTypes
import JWTKit
import NavigatorDAL
import NavigatorOIDCMiddleware
import OpenAPIRuntime
import Testing
import Vapor

@Suite("OIDCServerMiddleware")
struct OIDCServerMiddlewareTests {

    private let issuerURL = "https://test.example.com"
    private let clientID = "test-client"

    private func makeKeyCollection() async -> JWTKeyCollection {
        let keys = JWTKeyCollection()
        await keys.add(hmac: "test-secret-key-32-bytes-padded!!", digestAlgorithm: .sha256)
        return keys
    }

    private func makeToken(
        iss: String? = nil,
        sub: String = "oidc-test-sub",
        aud: String? = nil,
        keys: JWTKeyCollection
    ) async throws -> String {
        let payload = OIDCIDTokenPayload(
            iss: IssuerClaim(value: iss ?? issuerURL),
            sub: SubjectClaim(value: sub),
            aud: AudienceClaim(value: [aud ?? clientID]),
            exp: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            email: "oidc-test@example.com"
        )
        return try await keys.sign(payload)
    }

    private func makeMiddleware(database: Database) async -> OIDCServerMiddleware {
        let keys = await makeKeyCollection()
        return OIDCServerMiddleware(
            keyCollection: keys,
            issuerURL: issuerURL,
            clientID: clientID,
            database: database
        )
    }

    private let okNext:
        @Sendable (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws
            -> (HTTPResponse, HTTPBody?) = { _, _, _ in
                (HTTPResponse(status: .ok), nil)
            }

    @Test("Returns 401 when Authorization header is missing")
    func testMissingAuthorizationHeader() async throws {
        try await withDatabase { db in
            let middleware = await makeMiddleware(database: db)
            let request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/test")
            let (response, _) = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(pathParameters: [:]),
                operationID: "test",
                next: okNext
            )
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Returns 401 when JWT signature is invalid")
    func testInvalidJWT() async throws {
        try await withDatabase { db in
            let middleware = await makeMiddleware(database: db)
            var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/test")
            request.headerFields[.authorization] = "Bearer not.a.valid.jwt"
            let (response, _) = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(pathParameters: [:]),
                operationID: "test",
                next: okNext
            )
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Returns 401 when issuer does not match")
    func testBadIssuer() async throws {
        try await withDatabase { db in
            let keys = await makeKeyCollection()
            let middleware = await makeMiddleware(database: db)
            let token = try await makeToken(iss: "https://wrong-issuer.example.com", keys: keys)
            var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/test")
            request.headerFields[.authorization] = "Bearer \(token)"
            let (response, _) = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(pathParameters: [:]),
                operationID: "test",
                next: okNext
            )
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Returns 401 when audience does not match")
    func testBadAudience() async throws {
        try await withDatabase { db in
            let keys = await makeKeyCollection()
            let middleware = await makeMiddleware(database: db)
            let token = try await makeToken(aud: "wrong-client-id", keys: keys)
            var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/test")
            request.headerFields[.authorization] = "Bearer \(token)"
            let (response, _) = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(pathParameters: [:]),
                operationID: "test",
                next: okNext
            )
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Returns 401 when user sub is not in the database")
    func testUserNotFound() async throws {
        try await withDatabase { db in
            let keys = await makeKeyCollection()
            let middleware = await makeMiddleware(database: db)
            let token = try await makeToken(sub: "nonexistent-sub", keys: keys)
            var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/test")
            request.headerFields[.authorization] = "Bearer \(token)"
            let (response, _) = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(pathParameters: [:]),
                operationID: "test",
                next: okNext
            )
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Calls next and populates RequestLocals on valid token with known user")
    func testSuccess() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "oidc-middleware@example.com"
            person.name = "OIDC Middleware Test"
            try await person.save(on: db)

            let user = User()
            user.$person.id = person.id!
            user.role = .client
            user.sub = "oidc-middleware-sub"
            try await user.save(on: db)

            let keys = await makeKeyCollection()
            let middleware = await makeMiddleware(database: db)
            let token = try await makeToken(sub: "oidc-middleware-sub", keys: keys)
            var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/test")
            request.headerFields[.authorization] = "Bearer \(token)"

            let capture = RequestCapture()
            let capturingNext:
                @Sendable (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws
                    -> (HTTPResponse, HTTPBody?) = { _, _, _ in
                        await capture.record(
                            user: RequestLocals.authenticatedUser,
                            role: RequestLocals.userRole
                        )
                        return (HTTPResponse(status: .ok), nil)
                    }

            let (response, _) = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(pathParameters: [:]),
                operationID: "test",
                next: capturingNext
            )

            #expect(response.status == .ok)
            let capturedUser = await capture.user
            let capturedRole = await capture.role
            #expect(capturedUser?.sub == "oidc-middleware-sub")
            #expect(capturedRole == .client)
        }
    }
}

private actor RequestCapture {
    var user: AuthenticatedUser?
    var role: UserRole?

    func record(user: AuthenticatedUser?, role: UserRole?) {
        self.user = user
        self.role = role
    }
}
