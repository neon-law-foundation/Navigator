import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Entity person roles", .serialized)
struct AdminEntityAssignmentsTests {

    private func seed(
        db: Database
    ) async throws -> (entity: Entity, person: Person) {
        let entityType = try await EntityType.query(on: db).first()
        try #require(entityType != nil)
        let entity = Entity()
        entity.name = "Assign Co \(UUID().uuidString.prefix(4))"
        entity.$legalEntityType.id = entityType!.id!
        try await entity.save(on: db)
        let person = Person()
        person.name = "Entity Person"
        person.email = "ent-\(UUID().uuidString.prefix(6))@example.com"
        try await person.save(on: db)
        return (entity, person)
    }

    @Test("entity show renders the assign-a-person form")
    func entityShowHasAssignForm() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (entity, _) = try await seed(db: db)
            try await app.testing().test(
                .GET,
                "/admin/entities/\(entity.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("Assign a person"))
                    #expect(body.contains(#"name="personId""#))
                    #expect(body.contains(#"name="role""#))
                }
            )
        }
    }

    @Test("POST creates a PersonEntityRole row")
    func postCreatesEntityRole() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (entity, person) = try await seed(db: db)
            try await app.testing().test(
                .POST,
                "/admin/entities/\(entity.id!.uuidString)/roles",
                beforeRequest: { req in
                    try req.content.encode(
                        ["personId": person.id!.uuidString, "role": "admin"],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let row = try await PersonEntityRole.query(on: db)
                .filter(\.$person.$id == person.id!)
                .filter(\.$entity.$id == entity.id!)
                .first()
            #expect(row?.role == .admin)
        }
    }

    @Test("POST rejects duplicate person/entity pair")
    func postRejectsDuplicate() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (entity, person) = try await seed(db: db)
            let row = PersonEntityRole()
            row.$person.id = person.id!
            row.$entity.id = entity.id!
            row.role = .admin
            try await row.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/entities/\(entity.id!.uuidString)/roles",
                beforeRequest: { req in
                    try req.content.encode(
                        ["personId": person.id!.uuidString, "role": "admin"],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    let location = res.headers.first(name: .location) ?? ""
                    #expect(location.contains("assignment_error="))
                }
            )
            let count = try await PersonEntityRole.query(on: db)
                .filter(\.$entity.$id == entity.id!)
                .count()
            #expect(count == 1)
        }
    }

    @Test("DELETE removes an existing role")
    func deleteRemovesEntityRole() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let (entity, person) = try await seed(db: db)
            let row = PersonEntityRole()
            row.$person.id = person.id!
            row.$entity.id = entity.id!
            row.role = .admin
            try await row.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/entities/\(entity.id!.uuidString)/roles/\(row.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { _ in }
            )
            let reloaded = try await PersonEntityRole.find(row.id!, on: db)
            #expect(reloaded == nil)
        }
    }
}
