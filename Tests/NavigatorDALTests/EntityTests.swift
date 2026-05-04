import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Entity Database Operations")
struct EntityTests {

    @Test("Entity can be created with valid data")
    func testCreateEntity() async throws {
        try await withDatabase { db in
            // Create jurisdiction
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            // Create entity type
            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "Multi Member LLC"
            try await entityType.save(on: db)

            // Create entity
            let entity = Entity()
            entity.name = "Test LLC"
            entity.$legalEntityType.id = entityType.id!

            try await entity.save(on: db)

            #expect(entity.id != nil)
            #expect(entity.name == "Test LLC")
            #expect(entity.insertedAt != nil)
            #expect(entity.updatedAt != nil)
        }
    }

    @Test("Entity requires entity type")
    func testEntityTypeRequired() async throws {
        try await withDatabase { db in
            let entity = Entity()
            entity.name = "No Type Entity"

            // Expect error when entity type is not set
            await #expect(throws: Error.self) {
                try await entity.save(on: db)
            }
        }
    }

    @Test("Multiple entities can have same name with different types")
    func testSameNameDifferentTypes() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let llcType = EntityType()
            llcType.$jurisdiction.id = jurisdiction.id!
            llcType.name = "Single Member LLC"
            try await llcType.save(on: db)

            let corpType = EntityType()
            corpType.$jurisdiction.id = jurisdiction.id!
            corpType.name = "C-Corp"
            try await corpType.save(on: db)

            // Create two entities with same name but different types
            let llc = Entity()
            llc.name = "Acme Corp"
            llc.$legalEntityType.id = llcType.id!
            try await llc.save(on: db)

            let corp = Entity()
            corp.name = "Acme Corp"
            corp.$legalEntityType.id = corpType.id!
            try await corp.save(on: db)

            let entities = try await Entity.query(on: db)
                .filter(\.$name == "Acme Corp")
                .all()

            #expect(entities.count == 2)
        }
    }

    @Test("Entity can be queried by name")
    func testQueryByName() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "Family Trust"
            try await entityType.save(on: db)

            let entity = Entity()
            entity.name = "Smith Family Trust"
            entity.$legalEntityType.id = entityType.id!
            try await entity.save(on: db)

            let found = try await Entity.query(on: db)
                .filter(\.$name == "Smith Family Trust")
                .first()

            #expect(found != nil)
            #expect(found?.name == "Smith Family Trust")
        }
    }

    @Test("Entity can be queried with entity type relationship")
    func testQueryWithEntityType() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "501(c)(3) Non-Profit"
            try await entityType.save(on: db)

            let entity = Entity()
            entity.name = "Charity Foundation"
            entity.$legalEntityType.id = entityType.id!
            try await entity.save(on: db)

            let found = try await Entity.query(on: db)
                .with(\.$legalEntityType)
                .filter(\.$name == "Charity Foundation")
                .first()

            #expect(found != nil)
            #expect(found?.legalEntityType.name == "501(c)(3) Non-Profit")
        }
    }

    @Test("Entity can be updated")
    func testUpdateEntity() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let entityType = EntityType()
            entityType.$jurisdiction.id = jurisdiction.id!
            entityType.name = "Multi Member LLC"
            try await entityType.save(on: db)

            let entity = Entity()
            entity.name = "Original Name LLC"
            entity.$legalEntityType.id = entityType.id!
            try await entity.save(on: db)

            // Update name
            entity.name = "Updated Name LLC"
            try await entity.save(on: db)

            let updated = try await Entity.query(on: db)
                .filter(\.$id == entity.id!)
                .first()

            #expect(updated?.name == "Updated Name LLC")
        }
    }

    @Test("Multiple entities can be created")
    func testMultipleEntities() async throws {
        try await withDatabase { db in
            let jurisdiction = Jurisdiction()
            jurisdiction.name = "Nevada"
            jurisdiction.code = "NV"
            jurisdiction.jurisdictionType = .state
            try await jurisdiction.save(on: db)

            let llcType = EntityType()
            llcType.$jurisdiction.id = jurisdiction.id!
            llcType.name = "Multi Member LLC"
            try await llcType.save(on: db)

            // Create multiple entities
            let entity1 = Entity()
            entity1.name = "Shook Law LLC"
            entity1.$legalEntityType.id = llcType.id!
            try await entity1.save(on: db)

            let entity2 = Entity()
            entity2.name = "Sagebrush Services LLC"
            entity2.$legalEntityType.id = llcType.id!
            try await entity2.save(on: db)

            let entity3 = Entity()
            entity3.name = "Neon Law"
            entity3.$legalEntityType.id = llcType.id!
            try await entity3.save(on: db)

            let count = try await Entity.query(on: db).count()
            #expect(count == 3)
        }
    }
}
