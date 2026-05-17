import FluentKit
import Foundation
import HTTPTypes
import NavigatorDAL
import NavigatorDatabaseService
import OpenAPIRuntime
import Testing

@testable import NavigatorWeb

@Suite("Authorization", .serialized)
struct AuthorizationTests {

    private func createTestUser(
        _ dbService: DatabaseService,
        sub: String,
        role: UserRole
    ) async throws {
        let db = try await dbService.db
        let person = Person()
        person.name = sub
        person.email = "\(sub)@example.com"
        try await person.save(on: db)
        let user = User()
        user.$person.id = person.id!
        user.role = role
        user.sub = sub
        try await user.save(on: db)
    }

    private func makeMiddleware(dbService: DatabaseService) async throws -> AuthMiddleware {
        let db = try await dbService.db
        return AuthMiddleware(db: db)
    }

    private func callMiddleware(
        _ middleware: AuthMiddleware,
        authorization: String? = nil
    ) async throws -> HTTPResponse.Status {
        var headers = HTTPFields()
        if let auth = authorization {
            headers[.authorization] = auth
        }
        let request = HTTPRequest(
            method: .get,
            scheme: nil,
            authority: nil,
            path: "/test",
            headerFields: headers
        )
        let (response, _) = try await middleware.intercept(
            request,
            body: nil,
            metadata: ServerRequestMetadata(pathParameters: [:]),
            operationID: "test",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        return response.status
    }

    @Test("Missing Authorization header returns 401")
    func missingAuthHeader() async throws {
        try await withTestDatabaseService { dbService in
            let middleware = try await makeMiddleware(dbService: dbService)
            let status = try await callMiddleware(middleware)
            #expect(status == .unauthorized)
        }
    }

    @Test("Invalid Bearer token returns 401")
    func invalidBearerToken() async throws {
        try await withTestDatabaseService { dbService in
            let middleware = try await makeMiddleware(dbService: dbService)
            let status = try await callMiddleware(middleware, authorization: "Bearer not.a.valid.token")
            #expect(status == .unauthorized)
        }
    }

    @Test("Unknown sub returns 401")
    func unknownSub() async throws {
        try await withTestDatabaseService { dbService in
            let middleware = try await makeMiddleware(dbService: dbService)
            let token = TestJWT.token(sub: "unknown-sub")
            let status = try await callMiddleware(middleware, authorization: "Bearer \(token)")
            #expect(status == .unauthorized)
        }
    }

    @Test("Client user passes through")
    func clientRole() async throws {
        try await withTestDatabaseService { dbService in
            let sub = "client-sub"
            try await createTestUser(dbService, sub: sub, role: .client)
            let middleware = try await makeMiddleware(dbService: dbService)
            let token = TestJWT.token(sub: sub)
            let status = try await callMiddleware(middleware, authorization: "Bearer \(token)")
            #expect(status == .ok)
        }
    }

    @Test("Staff user passes through")
    func staffRole() async throws {
        try await withTestDatabaseService { dbService in
            let sub = "staff-sub"
            try await createTestUser(dbService, sub: sub, role: .staff)
            let middleware = try await makeMiddleware(dbService: dbService)
            let token = TestJWT.token(sub: sub)
            let status = try await callMiddleware(middleware, authorization: "Bearer \(token)")
            #expect(status == .ok)
        }
    }

    @Test("Admin user passes through")
    func adminRole() async throws {
        try await withTestDatabaseService { dbService in
            let sub = "admin-sub"
            try await createTestUser(dbService, sub: sub, role: .admin)
            let middleware = try await makeMiddleware(dbService: dbService)
            let token = TestJWT.token(sub: sub)
            let status = try await callMiddleware(middleware, authorization: "Bearer \(token)")
            #expect(status == .ok)
        }
    }

    @Test("Sub whose base64url payload contains underscore decodes correctly")
    func base64URLUnderscoreInPayload() async throws {
        try await withTestDatabaseService { dbService in
            // "abc?def" JSON-encodes to a base64url payload containing '_'; verifies
            // the base64URL → base64 conversion replaces '_' with '/' (not vice versa).
            let sub = "abc?def"
            try await createTestUser(dbService, sub: sub, role: .client)
            let middleware = try await makeMiddleware(dbService: dbService)
            let token = TestJWT.token(sub: sub)
            let status = try await callMiddleware(middleware, authorization: "Bearer \(token)")
            #expect(status == .ok)
        }
    }
}
