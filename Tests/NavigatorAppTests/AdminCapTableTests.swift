import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Share class CRUD", .serialized)
struct AdminShareClassCRUDTests {

    private func seedEntity(db: Database) async throws -> Entity {
        let type = try await EntityType.query(on: db).first()
        try #require(type != nil)
        let e = Entity()
        e.name = "Cap Co \(UUID().uuidString.prefix(4))"
        e.$legalEntityType.id = type!.id!
        try await e.save(on: db)
        return e
    }

    @Test("GET /admin/share-classes shows a New-share-class CTA")
    func indexHasCTA() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/share-classes",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"href="/admin/share-classes/new""#))
                    #expect(body.contains(">New share class<"))
                }
            )
        }
    }

    @Test("GET /admin/share-classes/new renders the compose form")
    func newFormRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/share-classes/new",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">New share class<"))
                    #expect(body.contains(#"name="name""#))
                    #expect(body.contains(#"name="entityId""#))
                    #expect(body.contains(#"name="priority""#))
                }
            )
        }
    }

    @Test("POST creates a row")
    func createPersists() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let name = "Series A \(UUID().uuidString.prefix(4))"
            try await app.testing().test(
                .POST,
                "/admin/share-classes",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "name": name,
                            "entityId": entity.id!.uuidString,
                            "priority": "100",
                            "description": "Preferred A",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let saved = try await ShareClass.query(on: db).filter(\.$name == name).first()
            #expect(saved?.priority == 100)
            #expect(saved?.description == "Preferred A")
        }
    }

    @Test("POST rejects duplicate (entity_id, priority) pair")
    func rejectsDuplicatePriority() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let existing = ShareClass()
            existing.name = "Original"
            existing.$entity.id = entity.id!
            existing.priority = 200
            try await existing.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/share-classes",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "name": "Imposter",
                            "entityId": entity.id!.uuidString,
                            "priority": "200",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    #expect(res.body.string.contains("Priority is already used on this entity."))
                }
            )
        }
    }

    @Test("PATCH updates and DELETE removes")
    func updateAndDelete() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let sc = ShareClass()
            sc.name = "Before"
            sc.$entity.id = entity.id!
            sc.priority = Int.random(in: 500..<5000)
            try await sc.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/share-classes/\(sc.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "_method": "PATCH",
                            "name": "After",
                            "entityId": entity.id!.uuidString,
                            "priority": String(sc.priority),
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let updated = try await ShareClass.find(sc.id!, on: db)
            #expect(updated?.name == "After")
            try await app.testing().test(
                .POST,
                "/admin/share-classes/\(sc.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { _ in }
            )
            #expect(try await ShareClass.find(sc.id!, on: db) == nil)
        }
    }
}

@Suite("Admin: Share issuance CRUD", .serialized)
struct AdminShareIssuanceCRUDTests {

    private func seedEntity(db: Database) async throws -> Entity {
        let type = try await EntityType.query(on: db).first()
        try #require(type != nil)
        let e = Entity()
        e.name = "Issuer \(UUID().uuidString.prefix(4))"
        e.$legalEntityType.id = type!.id!
        try await e.save(on: db)
        return e
    }

    @Test("GET /admin/share-issuances shows a New CTA")
    func indexHasCTA() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/share-issuances",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"href="/admin/share-issuances/new""#))
                    #expect(body.contains(">New issuance<"))
                }
            )
        }
    }

    @Test("New form renders entity + shareholderType + shareholder selects")
    func newFormRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/share-issuances/new",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"name="entityId""#))
                    #expect(body.contains(#"name="shareholderType""#))
                    #expect(body.contains(#"name="personShareholderId""#))
                    #expect(body.contains(#"name="entityShareholderId""#))
                }
            )
        }
    }

    @Test("POST with shareholderType=person creates a person-backed issuance")
    func createWithPersonShareholder() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let holder = Person()
            holder.name = "Shareholder"
            holder.email = "holder-\(UUID().uuidString.prefix(6))@example.com"
            try await holder.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/share-issuances",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "entityId": entity.id!.uuidString,
                            "shareholderType": "person",
                            "personShareholderId": holder.id!.uuidString,
                            "entityShareholderId": "",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let row = try await ShareIssuance.query(on: db)
                .filter(\.$entity.$id == entity.id!)
                .first()
            #expect(row?.shareholderType == .person)
            #expect(row?.shareholderId == holder.id!)
        }
    }

    @Test("POST with shareholderType=entity creates an entity-backed issuance")
    func createWithEntityShareholder() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let issuer = try await seedEntity(db: db)
            let holderEntity = try await seedEntity(db: db)
            try await app.testing().test(
                .POST,
                "/admin/share-issuances",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "entityId": issuer.id!.uuidString,
                            "shareholderType": "entity",
                            "personShareholderId": "",
                            "entityShareholderId": holderEntity.id!.uuidString,
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let row = try await ShareIssuance.query(on: db)
                .filter(\.$entity.$id == issuer.id!)
                .first()
            #expect(row?.shareholderType == .entity)
            #expect(row?.shareholderId == holderEntity.id!)
        }
    }

    @Test("DELETE removes the issuance")
    func deleteRemoves() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entity = try await seedEntity(db: db)
            let row = ShareIssuance()
            row.$entity.id = entity.id!
            row.shareholderType = .entity
            row.shareholderId = UUID()
            try await row.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/share-issuances/\(row.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { _ in }
            )
            #expect(try await ShareIssuance.find(row.id!, on: db) == nil)
        }
    }
}
