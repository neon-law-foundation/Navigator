import FluentKit
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Jurisdictions", .serialized)
struct AdminJurisdictionsTests {

    @Test("GET /admin/jurisdictions renders the list")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/jurisdictions",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">Jurisdictions<"))
                }
            )
        }
    }

    @Test("POST /admin/jurisdictions creates a row")
    func createJurisdiction() async throws {
        try await withApp(configure: testConfigure) { app in
            let code = "TT-\(UUID().uuidString.prefix(4))"
            try await app.testing().test(
                .POST,
                "/admin/jurisdictions",
                beforeRequest: { req in
                    try req.content.encode(
                        ["name": "Test Land", "code": code, "jurisdictionType": "state"],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let db = try await app.databaseService!.db
            let j = try await Jurisdiction.query(on: db).filter(\.$code == code).first()
            #expect(j?.name == "Test Land")
        }
    }
}

@Suite("Admin: Entity types", .serialized)
struct AdminEntityTypesTests {

    @Test("GET /admin/entity-types renders the list")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/entity-types",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">Entity types<"))
                }
            )
        }
    }

    @Test("POST /admin/entity-types creates a row")
    func createEntityType() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let jurisdiction = try await Jurisdiction.query(on: db).first()
            try #require(jurisdiction != nil)
            let name = "Test Type \(UUID().uuidString.prefix(4))"
            try await app.testing().test(
                .POST,
                "/admin/entity-types",
                beforeRequest: { req in
                    try req.content.encode(
                        ["name": name, "jurisdictionId": jurisdiction!.id!.uuidString],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let created = try await EntityType.query(on: db).filter(\.$name == name).first()
            #expect(created != nil)
        }
    }

    @Test("POST /admin/entity-types rejects unknown jurisdiction id")
    func rejectsBadJurisdictionId() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .POST,
                "/admin/entity-types",
                beforeRequest: { req in
                    try req.content.encode(
                        ["name": "Type X", "jurisdictionId": UUID().uuidString],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    #expect(res.body.string.contains("Pick a valid jurisdiction."))
                }
            )
        }
    }
}

@Suite("Admin: Entities", .serialized)
struct AdminEntitiesTests {

    @Test("GET /admin/entities renders the list")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/entities",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">Entities<"))
                }
            )
        }
    }

    @Test("POST /admin/entities creates with a valid entity type")
    func createEntity() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entityType = try await EntityType.query(on: db).first()
            try #require(entityType != nil)
            let name = "Test Co \(UUID().uuidString.prefix(4))"
            try await app.testing().test(
                .POST,
                "/admin/entities",
                beforeRequest: { req in
                    try req.content.encode(
                        ["name": name, "legalEntityTypeId": entityType!.id!.uuidString],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/entities") == true)
                }
            )
            let created = try await Entity.query(on: db).filter(\.$name == name).first()
            #expect(created != nil)
        }
    }

    @Test("POST /admin/entities rejects missing entity type")
    func rejectsMissingType() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .POST,
                "/admin/entities",
                beforeRequest: { req in
                    try req.content.encode(
                        ["name": "No Type", "legalEntityTypeId": ""],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    #expect(res.body.string.contains("Pick an entity type."))
                }
            )
        }
    }

    @Test("Entity round-trip: create, edit, delete")
    func crudRoundTrip() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entityType = try await EntityType.query(on: db).first()
            try #require(entityType != nil)
            let name = "Round \(UUID().uuidString.prefix(4))"
            let entity = Entity()
            entity.name = name
            entity.$legalEntityType.id = entityType!.id!
            try await entity.save(on: db)
            // PATCH to rename.
            try await app.testing().test(
                .POST,
                "/admin/entities/\(entity.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "_method": "PATCH", "name": "\(name) updated",
                            "legalEntityTypeId": entityType!.id!.uuidString,
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let updated = try await Entity.find(entity.id!, on: db)
            #expect(updated?.name == "\(name) updated")
            // DELETE.
            try await app.testing().test(
                .POST,
                "/admin/entities/\(entity.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { _ in }
            )
            let gone = try await Entity.find(entity.id!, on: db)
            #expect(gone == nil)
        }
    }
}
