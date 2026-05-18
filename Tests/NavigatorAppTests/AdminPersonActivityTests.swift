import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Person activity timeline", .serialized)
struct AdminPersonActivityTests {

    private func seedPerson(db: Database) async throws -> Person {
        let p = Person()
        p.name = "Activity Subject \(UUID().uuidString.prefix(4))"
        p.email = "act-\(UUID().uuidString.prefix(6))@example.com"
        try await p.save(on: db)
        return p
    }

    @Test("show page renders an Activity section with the created event")
    func activitySectionRendersCreatedEvent() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = try await seedPerson(db: db)
            try await app.testing().test(
                .GET,
                "/admin/people/\(person.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Activity<"))
                    #expect(body.contains(#"data-kind="created""#))
                    #expect(body.contains("\(person.name) added to the directory."))
                }
            )
        }
    }

    @Test("PersonProjectRole insert shows up as a projectAssigned event")
    func surfacesProjectAssignment() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = try await seedPerson(db: db)
            let project = Project()
            project.codename = "personact-\(UUID().uuidString.prefix(4))"
            try await project.save(on: db)
            let r = PersonProjectRole()
            r.$person.id = person.id!
            r.$project.id = project.id!
            r.role = .staff
            try await r.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/people/\(person.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="projectAssigned""#))
                    #expect(body.contains("Assigned to \(project.codename) as staff."))
                }
            )
        }
    }

    @Test("PersonEntityRole insert shows up as an entityRoleAssigned event")
    func surfacesEntityRoleAssignment() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = try await seedPerson(db: db)
            let entityType = try await EntityType.query(on: db).first()
            try #require(entityType != nil)
            let entity = Entity()
            entity.name = "Personact Co \(UUID().uuidString.prefix(4))"
            entity.$legalEntityType.id = entityType!.id!
            try await entity.save(on: db)
            let role = PersonEntityRole()
            role.$person.id = person.id!
            role.$entity.id = entity.id!
            role.role = .admin
            try await role.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/people/\(person.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="entityRoleAssigned""#))
                    #expect(body.contains("Took the admin role on \(entity.name)."))
                }
            )
        }
    }

    @Test("Credential insert shows up as a credentialIssued event")
    func surfacesCredential() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = try await seedPerson(db: db)
            let jurisdiction = try await Jurisdiction.query(on: db).first()
            try #require(jurisdiction != nil)
            let c = Credential()
            c.$person.id = person.id!
            c.$jurisdiction.id = jurisdiction!.id!
            c.licenseNumber = "LIC-\(UUID().uuidString.prefix(6))"
            try await c.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/people/\(person.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="credentialIssued""#))
                    #expect(body.contains(c.licenseNumber))
                }
            )
        }
    }

    @Test("activity timeline orders events newest-first")
    func ordersNewestFirst() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = try await seedPerson(db: db)
            let project = Project()
            project.codename = "personact-order-\(UUID().uuidString.prefix(4))"
            try await project.save(on: db)
            let r = PersonProjectRole()
            r.$person.id = person.id!
            r.$project.id = project.id!
            r.role = .client
            try await r.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/people/\(person.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    guard
                        let assignedRange = body.range(
                            of: #"data-kind="projectAssigned""#
                        )?.lowerBound,
                        let createdRange = body.range(of: #"data-kind="created""#)?.lowerBound
                    else {
                        Issue.record("Expected both kinds to render.")
                        return
                    }
                    #expect(assignedRange < createdRange)
                }
            )
        }
    }
}
