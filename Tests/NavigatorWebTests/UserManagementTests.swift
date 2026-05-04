import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorOIDCMiddleware
import Testing

@testable import NavigatorWeb

@Suite("User Management API", .serialized)
struct UserManagementTests {

    private func makeHandler(dbService: DatabaseService) async throws -> APIHandler {
        let db = try await dbService.db
        return APIHandler(
            db: db,
            databaseService: dbService,
            emailService: EmailService(),
            storageService: StorageService(bucketURL: ""),
            authMiddleware: AuthMiddleware(db: db),
            mailIngestSecret: "test-secret"
        )
    }

    private func createPerson(
        _ db: Database,
        name: String,
        email: String
    ) async throws -> Person {
        let person = Person()
        person.name = name
        person.email = email
        try await person.save(on: db)
        return person
    }

    private func createUser(
        _ db: Database,
        person: Person,
        sub: String,
        role: UserRole
    ) async throws -> User {
        let user = User()
        user.$person.id = person.id!
        user.role = role
        user.sub = sub
        try await user.save(on: db)
        return user
    }

    private func withAuthContext<T: Sendable>(
        sub: String,
        role: UserRole,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let authenticatedUser: AuthenticatedUser? = AuthenticatedUser(sub: sub, email: nil)
        let optRole: UserRole? = role
        return try await NavigatorOIDCMiddleware.RequestLocals.$authenticatedUser.withValue(
            authenticatedUser
        ) {
            try await NavigatorOIDCMiddleware.RequestLocals.$userRole.withValue(optRole) {
                try await operation()
            }
        }
    }

    // MARK: - listUsers

    @Test("listUsers returns all users for admin")
    func listUsersAdmin() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let p1 = try await createPerson(db, name: "Alice", email: "alice@example.com")
        let _ = try await createUser(db, person: p1, sub: "alice-sub", role: .admin)
        let p2 = try await createPerson(db, name: "Bob", email: "bob@example.com")
        let _ = try await createUser(db, person: p2, sub: "bob-sub", role: .client)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "alice-sub", role: .admin) {
            try await handler.listUsers(.init(query: .init()))
        }

        if case .ok(let response) = output {
            if case .json(let users) = response.body {
                let emails = users.map { $0.email }
                #expect(emails.contains("alice@example.com"))
                #expect(emails.contains("bob@example.com"))
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        await dbService.shutdown()
    }

    @Test("listUsers returns 403 for non-admin")
    func listUsersNonAdmin() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let p1 = try await createPerson(db, name: "Staff", email: "staff@example.com")
        let _ = try await createUser(db, person: p1, sub: "staff-sub", role: .staff)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "staff-sub", role: .staff) {
            try await handler.listUsers(.init(query: .init()))
        }

        if case .undocumented(let statusCode, _) = output {
            #expect(statusCode == 403)
        } else {
            Issue.record("Expected 403 for non-admin")
        }

        await dbService.shutdown()
    }

    @Test("listUsers filters by role")
    func listUsersFilterByRole() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let p1 = try await createPerson(db, name: "Admin", email: "admin@example.com")
        let _ = try await createUser(db, person: p1, sub: "admin-sub", role: .admin)
        let p2 = try await createPerson(db, name: "Client", email: "client@example.com")
        let _ = try await createUser(db, person: p2, sub: "client-sub", role: .client)
        let p3 = try await createPerson(db, name: "Staff", email: "staff@example.com")
        let _ = try await createUser(db, person: p3, sub: "staff-sub", role: .staff)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.listUsers(.init(query: .init(role: .client)))
        }

        if case .ok(let response) = output {
            if case .json(let users) = response.body {
                let allClient = users.allSatisfy { $0.role == .client }
                #expect(allClient)
                let emails = users.map { $0.email }
                #expect(emails.contains("client@example.com"))
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        await dbService.shutdown()
    }

    @Test("listUsers searches by email substring")
    func listUsersSearchByEmail() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let p1 = try await createPerson(db, name: "Admin", email: "admin@example.com")
        let _ = try await createUser(db, person: p1, sub: "admin-sub", role: .admin)
        let p2 = try await createPerson(db, name: "Bob", email: "bob@company.com")
        let _ = try await createUser(db, person: p2, sub: "bob-sub", role: .client)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.listUsers(.init(query: .init(q: "company")))
        }

        if case .ok(let response) = output {
            if case .json(let users) = response.body {
                #expect(users.count == 1)
                #expect(users[0].email == "bob@company.com")
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        await dbService.shutdown()
    }

    // MARK: - getUser

    @Test("getUser returns user detail for admin")
    func getUserAdmin() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let p1 = try await createPerson(db, name: "Admin", email: "admin@example.com")
        let _ = try await createUser(db, person: p1, sub: "admin-sub", role: .admin)
        let p2 = try await createPerson(db, name: "Target", email: "target@example.com")
        let target = try await createUser(db, person: p2, sub: "target-sub", role: .client)
        let targetID = target.id!

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.getUser(.init(path: .init(id: targetID)))
        }

        if case .ok(let response) = output {
            if case .json(let detail) = response.body {
                #expect(detail.id == targetID)
                #expect(detail.email == "target@example.com")
                #expect(detail.role == .client)
                #expect(detail.personId == p2.id!)
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        await dbService.shutdown()
    }

    @Test("getUser returns 403 for non-admin")
    func getUserNonAdmin() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "client-sub", role: .client) {
            try await handler.getUser(.init(path: .init(id: UUID())))
        }

        if case .undocumented(let statusCode, _) = output {
            #expect(statusCode == 403)
        } else {
            Issue.record("Expected 403 for non-admin")
        }

        await dbService.shutdown()
    }

    @Test("getUser returns 404 for unknown ID")
    func getUserNotFound() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.getUser(.init(path: .init(id: UUID())))
        }

        if case .notFound = output {
            // pass
        } else {
            Issue.record("Expected 404 for unknown user ID")
        }

        await dbService.shutdown()
    }

    // MARK: - updateUserRole

    @Test("updateUserRole changes role and writes audit row")
    func updateUserRoleHappyPath() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let adminPerson = try await createPerson(db, name: "Admin", email: "admin@example.com")
        let _ = try await createUser(db, person: adminPerson, sub: "admin-sub", role: .admin)
        let targetPerson = try await createPerson(db, name: "Target", email: "target@example.com")
        let target = try await createUser(
            db,
            person: targetPerson,
            sub: "target-sub",
            role: .client
        )
        let targetID = target.id!

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.updateUserRole(
                .init(
                    path: .init(id: targetID),
                    body: .json(.init(role: .staff, reason: "Promoting for workshop"))
                )
            )
        }

        if case .ok(let response) = output {
            if case .json(let detail) = response.body {
                #expect(detail.role == .staff)
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        let audits = try await UserRoleAudit.query(on: db).all()
        #expect(audits.count == 1)
        #expect(audits[0].previousRole == .client)
        #expect(audits[0].newRole == .staff)
        #expect(audits[0].reason == "Promoting for workshop")

        await dbService.shutdown()
    }

    @Test("updateUserRole returns 403 for non-admin")
    func updateUserRoleNonAdmin() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "staff-sub", role: .staff) {
            try await handler.updateUserRole(
                .init(
                    path: .init(id: UUID()),
                    body: .json(.init(role: .admin, reason: "Self-promote"))
                )
            )
        }

        if case .undocumented(let statusCode, _) = output {
            #expect(statusCode == 403)
        } else {
            Issue.record("Expected 403 for non-admin")
        }

        await dbService.shutdown()
    }

    @Test("updateUserRole returns 403 when admin demotes themselves")
    func updateUserRoleSelfDemotion() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let adminPerson = try await createPerson(db, name: "Admin", email: "admin@example.com")
        let admin = try await createUser(db, person: adminPerson, sub: "admin-sub", role: .admin)
        let adminID = admin.id!

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.updateUserRole(
                .init(
                    path: .init(id: adminID),
                    body: .json(.init(role: .client, reason: "Demoting myself"))
                )
            )
        }

        if case .undocumented(let statusCode, _) = output {
            #expect(statusCode == 403)
        } else {
            Issue.record("Expected 403 for self-demotion")
        }

        await dbService.shutdown()
    }

    @Test("updateUserRole returns 404 for unknown user")
    func updateUserRoleNotFound() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let adminPerson = try await createPerson(db, name: "Admin", email: "admin@example.com")
        let _ = try await createUser(db, person: adminPerson, sub: "admin-sub", role: .admin)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.updateUserRole(
                .init(
                    path: .init(id: UUID()),
                    body: .json(.init(role: .staff, reason: "No such user"))
                )
            )
        }

        if case .notFound = output {
            // pass
        } else {
            Issue.record("Expected 404 for unknown user")
        }

        await dbService.shutdown()
    }

    // MARK: - getUserRoleHistory

    @Test("getUserRoleHistory returns audit entries newest-first")
    func getUserRoleHistoryOrder() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()
        let db = try await dbService.db

        let adminPerson = try await createPerson(db, name: "Admin", email: "admin@example.com")
        let admin = try await createUser(db, person: adminPerson, sub: "admin-sub", role: .admin)
        let targetPerson = try await createPerson(db, name: "Target", email: "target@example.com")
        let target = try await createUser(
            db,
            person: targetPerson,
            sub: "target-sub",
            role: .client
        )
        let targetID = target.id!
        let adminID = admin.id!

        let audit1 = UserRoleAudit()
        audit1.$user.id = targetID
        audit1.$changedByUser.id = adminID
        audit1.previousRole = .client
        audit1.newRole = .staff
        audit1.reason = "First change"
        try await audit1.save(on: db)

        let audit2 = UserRoleAudit()
        audit2.$user.id = targetID
        audit2.$changedByUser.id = adminID
        audit2.previousRole = .staff
        audit2.newRole = .admin
        audit2.reason = "Second change"
        try await audit2.save(on: db)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.getUserRoleHistory(.init(path: .init(id: targetID)))
        }

        if case .ok(let response) = output {
            if case .json(let entries) = response.body {
                #expect(entries.count == 2)
                #expect(entries[0].reason == "Second change")
                #expect(entries[1].reason == "First change")
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        await dbService.shutdown()
    }

    @Test("getUserRoleHistory returns 403 for non-admin")
    func getUserRoleHistoryNonAdmin() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "client-sub", role: .client) {
            try await handler.getUserRoleHistory(.init(path: .init(id: UUID())))
        }

        if case .undocumented(let statusCode, _) = output {
            #expect(statusCode == 403)
        } else {
            Issue.record("Expected 403 for non-admin")
        }

        await dbService.shutdown()
    }

    @Test("getUserRoleHistory returns 404 for unknown user")
    func getUserRoleHistoryNotFound() async throws {
        let dbService = DatabaseService(configuration: .memory)
        try await dbService.migrate()

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.getUserRoleHistory(.init(path: .init(id: UUID())))
        }

        if case .notFound = output {
            // pass
        } else {
            Issue.record("Expected 404 for unknown user")
        }

        await dbService.shutdown()
    }
}
