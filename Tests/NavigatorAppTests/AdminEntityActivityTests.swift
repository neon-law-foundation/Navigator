import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Entity activity timeline", .serialized)
struct AdminEntityActivityTests {

    private func seedEntity(db: Database) async throws -> Entity {
        let entityType = try await EntityType.query(on: db).first()
        try #require(entityType != nil)
        let e = Entity()
        e.name = "Activity Co \(UUID().uuidString.prefix(4))"
        e.$legalEntityType.id = entityType!.id!
        try await e.save(on: db)
        return e
    }

    @Test("show page renders an Activity section with the created event")
    func activitySectionRendersCreatedEvent() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            try await app.testing().test(
                .GET,
                "/admin/entities/\(entity.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Activity<"))
                    #expect(body.contains(#"data-kind="created""#))
                    #expect(body.contains("\(entity.name) added to the directory."))
                }
            )
        }
    }

    @Test("PersonEntityRole shows up as a personAssigned event")
    func surfacesPersonAssignment() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let person = Person()
            person.name = "Entity Activity Person"
            person.email = "eap-\(UUID().uuidString.prefix(6))@example.com"
            try await person.save(on: db)
            let role = PersonEntityRole()
            role.$person.id = person.id!
            role.$entity.id = entity.id!
            role.role = .admin
            try await role.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/entities/\(entity.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="personAssigned""#))
                    #expect(body.contains("\(person.name) joined as admin."))
                }
            )
        }
    }

    @Test("ShareClass insert shows up as a shareClassAdded event")
    func surfacesShareClass() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let sc = ShareClass()
            sc.name = "Common-\(UUID().uuidString.prefix(4))"
            sc.$entity.id = entity.id!
            sc.priority = Int.random(in: 100..<10000)
            try await sc.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/entities/\(entity.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="shareClassAdded""#))
                    #expect(body.contains("Share class \(sc.name) added"))
                }
            )
        }
    }

    @Test("ShareIssuance insert shows up as a shareIssuanceMade event")
    func surfacesShareIssuance() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let issuance = ShareIssuance()
            issuance.$entity.id = entity.id!
            issuance.shareholderType = .entity
            issuance.shareholderId = UUID()
            try await issuance.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/entities/\(entity.id!.uuidString)",
                afterResponse: { res async in
                    #expect(res.body.string.contains(#"data-kind="shareIssuanceMade""#))
                }
            )
        }
    }

    @Test("Address insert shows up as an addressAdded event")
    func surfacesAddress() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let a = Address()
            a.$entity.id = entity.id!
            a.street = "123 Test St"
            a.city = "Testville"
            a.country = "US"
            a.isVerified = false
            try await a.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/entities/\(entity.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="addressAdded""#))
                    #expect(body.contains("Address added"))
                }
            )
        }
    }
}
