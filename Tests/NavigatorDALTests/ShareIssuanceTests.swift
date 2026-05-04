import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("ShareIssuance Database Operations")
struct ShareIssuanceTests {

    private func makeEntity(name: String, on db: Database) async throws -> Entity {
        let jurisdiction = Jurisdiction()
        jurisdiction.name = "Nevada-\(name)"
        jurisdiction.code = "NV-\(name.prefix(4))"
        jurisdiction.jurisdictionType = .state
        try await jurisdiction.save(on: db)

        let entityType = EntityType()
        entityType.$jurisdiction.id = jurisdiction.id!
        entityType.name = "C-Corp-\(name)"
        try await entityType.save(on: db)

        let entity = Entity()
        entity.name = name
        entity.$legalEntityType.id = entityType.id!
        try await entity.save(on: db)
        return entity
    }

    private func makePerson(name: String, on db: Database) async throws -> Person {
        let person = Person()
        person.name = name
        person.email = "\(name.lowercased())@example.com"
        try await person.save(on: db)
        return person
    }

    @Test("Can create a ShareIssuance with a Person shareholder")
    func testCreateWithPersonShareholder() async throws {
        try await withDatabase { db in
            let entity = try await makeEntity(name: "Acme Corp", on: db)
            let person = try await makePerson(name: "Alice", on: db)

            let issuance = ShareIssuance()
            issuance.$entity.id = entity.id!
            issuance.shareholderType = .person
            issuance.shareholderId = person.id!

            let repo = ShareIssuanceRepository(database: db)
            let created = try await repo.create(issuance: issuance)
            #expect(created.id != nil)
            #expect(created.shareholderType == .person)
            #expect(created.shareholderId == person.id!)
            #expect(created.$document.id == nil)
        }
    }

    @Test("Can create a ShareIssuance with an Entity shareholder")
    func testCreateWithEntityShareholder() async throws {
        try await withDatabase { db in
            let issuer = try await makeEntity(name: "Issuer Corp", on: db)
            let shareholder = try await makeEntity(name: "Holding LLC", on: db)

            let issuance = ShareIssuance()
            issuance.$entity.id = issuer.id!
            issuance.shareholderType = .entity
            issuance.shareholderId = shareholder.id!

            let repo = ShareIssuanceRepository(database: db)
            let created = try await repo.create(issuance: issuance)
            #expect(created.shareholderType == .entity)
            #expect(created.shareholderId == shareholder.id!)
        }
    }

    @Test("Can create a ShareIssuance with a document blob")
    func testCreateWithDocument() async throws {
        try await withDatabase { db in
            let entity = try await makeEntity(name: "Document Corp", on: db)
            let person = try await makePerson(name: "Bob", on: db)

            let blob = Blob()
            blob.objectStorageUrl = "s3://bucket/share-issuances/cert.pdf"
            blob.referencedBy = .shareIssuances
            blob.referencedById = UUID()
            try await blob.save(on: db)

            let issuance = ShareIssuance()
            issuance.$entity.id = entity.id!
            issuance.shareholderType = .person
            issuance.shareholderId = person.id!
            issuance.$document.id = blob.id

            let repo = ShareIssuanceRepository(database: db)
            let created = try await repo.create(issuance: issuance)
            #expect(created.$document.id == blob.id)

            let found = try await repo.find(id: created.id!)
            #expect(found?.$document.id == blob.id)
        }
    }

    @Test("Can find all issuances for an entity")
    func testFindByEntity() async throws {
        try await withDatabase { db in
            let entity = try await makeEntity(name: "Multi Issuance Corp", on: db)
            let person = try await makePerson(name: "Carol", on: db)

            let repo = ShareIssuanceRepository(database: db)

            let issuance1 = ShareIssuance()
            issuance1.$entity.id = entity.id!
            issuance1.shareholderType = .person
            issuance1.shareholderId = person.id!
            _ = try await repo.create(issuance: issuance1)

            let issuance2 = ShareIssuance()
            issuance2.$entity.id = entity.id!
            issuance2.shareholderType = .person
            issuance2.shareholderId = person.id!
            _ = try await repo.create(issuance: issuance2)

            let issuances = try await repo.findByEntity(entityId: entity.id!)
            #expect(issuances.count == 2)
        }
    }

    @Test("Can eager load entity from ShareIssuance")
    func testEagerLoadEntity() async throws {
        try await withDatabase { db in
            let entity = try await makeEntity(name: "Eager Corp", on: db)
            let person = try await makePerson(name: "Dave", on: db)

            let issuance = ShareIssuance()
            issuance.$entity.id = entity.id!
            issuance.shareholderType = .person
            issuance.shareholderId = person.id!
            try await issuance.save(on: db)

            let loaded = try await ShareIssuance.query(on: db)
                .filter(\.$id == issuance.id!)
                .with(\.$entity)
                .first()

            #expect(loaded?.entity.name == "Eager Corp")
        }
    }

    @Test("Can delete a ShareIssuance")
    func testDeleteIssuance() async throws {
        try await withDatabase { db in
            let entity = try await makeEntity(name: "Delete Corp", on: db)
            let person = try await makePerson(name: "Eve", on: db)

            let issuance = ShareIssuance()
            issuance.$entity.id = entity.id!
            issuance.shareholderType = .person
            issuance.shareholderId = person.id!

            let repo = ShareIssuanceRepository(database: db)
            let created = try await repo.create(issuance: issuance)
            let id = created.id!

            try await repo.delete(id: id)

            let found = try await repo.find(id: id)
            #expect(found == nil)
        }
    }

    @Test("ShareholderType enum has correct raw values")
    func testShareholderTypeRawValues() {
        #expect(ShareholderType.person.rawValue == "person")
        #expect(ShareholderType.entity.rawValue == "entity")
        #expect(ShareholderType.allCases.count == 2)
    }
}
