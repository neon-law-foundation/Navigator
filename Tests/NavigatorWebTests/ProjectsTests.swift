import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorOIDCMiddleware
import Testing

@testable import NavigatorWeb

@Suite("Projects API", .serialized)
struct ProjectsTests {

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

    private func createProject(_ db: Database, codename: String) async throws -> Project {
        let project = Project()
        project.codename = codename
        try await project.save(on: db)
        return project
    }

    private func assignPersonToProject(
        _ db: Database,
        person: Person,
        project: Project,
        role: ProjectRole
    ) async throws {
        let ppr = PersonProjectRole()
        ppr.$person.id = person.id!
        ppr.$project.id = project.id!
        ppr.role = role
        try await ppr.save(on: db)
    }

    private func withAuthContext<T: Sendable>(
        sub: String,
        role: UserRole,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let authenticatedUser: AuthenticatedUser? = AuthenticatedUser(sub: sub, email: nil)
        let optRole: UserRole? = role
        return try await withTaskLocals(authenticatedUser: authenticatedUser, role: optRole) {
            try await operation()
        }
    }

    private func withTaskLocals<T: Sendable>(
        authenticatedUser: AuthenticatedUser?,
        role: UserRole?,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await NavigatorOIDCMiddleware.RequestLocals.$authenticatedUser.withValue(authenticatedUser) {
            try await NavigatorOIDCMiddleware.RequestLocals.$userRole.withValue(role) {
                try await operation()
            }
        }
    }

    @Test("Admin receives all seeded projects")
    func adminSeesAllProjects() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let db = try await dbService.db

        let p1 = try await createProject(db, codename: "alpha")
        let p2 = try await createProject(db, codename: "beta")
        let _ = try await createProject(db, codename: "gamma")

        let adminPerson = try await createPerson(db, name: "Admin User", email: "admin@example.com")
        let _ = try await createUser(db, person: adminPerson, sub: "admin-sub", role: .admin)
        try await assignPersonToProject(db, person: adminPerson, project: p1, role: .staff)
        try await assignPersonToProject(db, person: adminPerson, project: p2, role: .staff)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.listProjects(.init())
        }

        if case .ok(let response) = output {
            if case .json(let summaries) = response.body {
                let codenames = summaries.map { $0.codename }
                #expect(codenames.contains("alpha"))
                #expect(codenames.contains("beta"))
                #expect(codenames.contains("gamma"))
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        await dbService.shutdown()
    }

    @Test("Staff receives only their assigned project")
    func staffSeesOnlyAssignedProject() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let db = try await dbService.db

        let projectA = try await createProject(db, codename: "project-a")
        let _ = try await createProject(db, codename: "project-b")
        let _ = try await createProject(db, codename: "project-c")

        let staffPerson = try await createPerson(db, name: "Staff User", email: "staff@example.com")
        let _ = try await createUser(db, person: staffPerson, sub: "staff-sub", role: .staff)
        try await assignPersonToProject(db, person: staffPerson, project: projectA, role: .staff)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "staff-sub", role: .staff) {
            try await handler.listProjects(.init())
        }

        if case .ok(let response) = output {
            if case .json(let summaries) = response.body {
                #expect(summaries.count == 1)
                #expect(summaries[0].codename == "project-a")
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        await dbService.shutdown()
    }

    @Test("Client receives only their assigned project")
    func clientSeesOnlyAssignedProject() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let db = try await dbService.db

        let projectX = try await createProject(db, codename: "project-x")
        let _ = try await createProject(db, codename: "project-y")
        let _ = try await createProject(db, codename: "project-z")

        let clientPerson = try await createPerson(
            db,
            name: "Client User",
            email: "client@example.com"
        )
        let _ = try await createUser(db, person: clientPerson, sub: "client-sub", role: .client)
        try await assignPersonToProject(db, person: clientPerson, project: projectX, role: .client)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "client-sub", role: .client) {
            try await handler.listProjects(.init())
        }

        if case .ok(let response) = output {
            if case .json(let summaries) = response.body {
                #expect(summaries.count == 1)
                #expect(summaries[0].codename == "project-x")
            } else {
                Issue.record("Expected json body")
            }
        } else {
            Issue.record("Expected ok response")
        }

        await dbService.shutdown()
    }

    @Test("No authenticatedUser returns 401")
    func missingAuthenticatedUserReturns401() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()

        let handler = try await makeHandler(dbService: dbService)

        let output = try await handler.listProjects(.init())

        if case .undocumented(let statusCode, _) = output {
            #expect(statusCode == 401)
        } else {
            Issue.record("Expected undocumented 401 response")
        }

        await dbService.shutdown()
    }

    @Test("getProject returns 404 for unknown ID")
    func getProjectReturns404ForUnknownID() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "admin-sub", role: .admin) {
            try await handler.getProject(.init(path: .init(id: UUID())))
        }

        if case .notFound = output {
            // pass
        } else {
            Issue.record("Expected 404 response for unknown project ID")
        }

        await dbService.shutdown()
    }

    @Test("createProject returns 403 for client role")
    func createProjectReturns403ForClient() async throws {
        let dbService = (try DatabaseService.fromEnvironment(defaultSQLitePath: ":memory:"))
        try await dbService.migrate()
        let db = try await dbService.db

        let clientPerson = try await createPerson(db, name: "Client User", email: "client@example.com")
        let _ = try await createUser(db, person: clientPerson, sub: "client-sub", role: .client)

        let handler = try await makeHandler(dbService: dbService)
        let output = try await withAuthContext(sub: "client-sub", role: .client) {
            try await handler.createProject(
                .init(body: .json(.init(codename: "test-project", title: nil, projectType: nil)))
            )
        }

        if case .forbidden = output {
            // pass
        } else {
            Issue.record("Expected 403 response for client role")
        }

        await dbService.shutdown()
    }

}
