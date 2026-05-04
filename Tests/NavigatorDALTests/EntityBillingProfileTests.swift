import Fluent
import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import SQLKit
import Testing
import Vapor

@Suite("EntityBillingProfile Database Operations")
struct EntityBillingProfileTests {

    @Test("Repository create + read round-trips a billing profile")
    func testCreateAndFind() async throws {
        try await withDatabase { db in
            let entityId = try await makeEntity(on: db)
            let repo = EntityBillingProfileRepository(database: db)

            let profile = EntityBillingProfile()
            profile.$entity.id = entityId
            profile.provider = .xero
            profile.externalContactId = "11111111-1111-1111-1111-111111111111"

            let created = try await repo.create(model: profile)
            #expect(created.id != nil)

            let reloaded = try #require(try await repo.find(id: created.id!))
            #expect(reloaded.$entity.id == entityId)
            #expect(reloaded.provider == .xero)
            #expect(reloaded.externalContactId == "11111111-1111-1111-1111-111111111111")
        }
    }

    @Test("findByExternalContact returns the matching profile")
    func testFindByExternalContact() async throws {
        try await withDatabase { db in
            let entityId = try await makeEntity(on: db)
            let repo = EntityBillingProfileRepository(database: db)

            let profile = EntityBillingProfile()
            profile.$entity.id = entityId
            profile.provider = .xero
            profile.externalContactId = "22222222-2222-2222-2222-222222222222"
            _ = try await repo.create(model: profile)

            let found = try await repo.findByExternalContact(
                provider: .xero,
                externalContactId: "22222222-2222-2222-2222-222222222222"
            )
            #expect(found?.id == profile.id)

            let missing = try await repo.findByExternalContact(
                provider: .xero,
                externalContactId: "ffffffff-ffff-ffff-ffff-ffffffffffff"
            )
            #expect(missing == nil)
        }
    }

    @Test("findForEntity returns the matching profile")
    func testFindForEntity() async throws {
        try await withDatabase { db in
            let entityId = try await makeEntity(on: db)
            let repo = EntityBillingProfileRepository(database: db)

            let profile = EntityBillingProfile()
            profile.$entity.id = entityId
            profile.provider = .xero
            profile.externalContactId = "33333333-3333-3333-3333-333333333333"
            _ = try await repo.create(model: profile)

            let found = try await repo.findForEntity(entityId: entityId, provider: .xero)
            #expect(found?.id == profile.id)
        }
    }

    @Test("UNIQUE (provider, external_contact_id) rejects duplicate mirrors")
    func testUniqueProviderExternalContactId() async throws {
        try await withDatabase { db in
            let entityA = try await makeEntity(on: db, name: "Entity A")
            let entityB = try await makeEntity(on: db, name: "Entity B")
            let repo = EntityBillingProfileRepository(database: db)

            let first = EntityBillingProfile()
            first.$entity.id = entityA
            first.provider = .xero
            first.externalContactId = "dup-contact-id"
            _ = try await repo.create(model: first)

            let duplicate = EntityBillingProfile()
            duplicate.$entity.id = entityB
            duplicate.provider = .xero
            duplicate.externalContactId = "dup-contact-id"

            await #expect(throws: (any Error).self) {
                _ = try await repo.create(model: duplicate)
            }
        }
    }

    @Test("UNIQUE (entity_id, provider) enforces one profile per entity per provider")
    func testUniqueEntityProvider() async throws {
        try await withDatabase { db in
            let entityId = try await makeEntity(on: db)
            let repo = EntityBillingProfileRepository(database: db)

            let first = EntityBillingProfile()
            first.$entity.id = entityId
            first.provider = .xero
            first.externalContactId = "contact-one"
            _ = try await repo.create(model: first)

            let second = EntityBillingProfile()
            second.$entity.id = entityId
            second.provider = .xero
            second.externalContactId = "contact-two"

            await #expect(throws: (any Error).self) {
                _ = try await repo.create(model: second)
            }
        }
    }

    @Test("provider CHECK constraint rejects an unknown provider on Postgres")
    func testProviderCheckConstraint() async throws {
        try await withDatabase { db in
            guard let sql = db as? SQLDatabase else {
                return
            }
            // The CHECK constraint is Postgres-only; SQLite (used in the default test
            // harness) does not support `ALTER TABLE ... ADD CONSTRAINT ... CHECK`, so
            // skip the assertion there. The assertion only runs when tests are pointed
            // at a real Postgres instance.
            guard sql.dialect.name == "postgresql" else {
                return
            }

            let entityId = try await makeEntity(on: db)

            await #expect(throws: (any Error).self) {
                try await sql.raw(
                    """
                    INSERT INTO entity_billing_profiles
                        (entity_id, provider, external_contact_id,
                         inserted_at, updated_at)
                    VALUES
                        (\(bind: entityId), 'stripe', 'whatever',
                         CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """
                ).run()
            }
        }
    }

    // MARK: - Helpers

    private func makeEntity(on db: Database, name: String = "Test Entity") async throws -> UUID {
        let jurisdiction = Jurisdiction()
        jurisdiction.code = "NV-\(UUID().uuidString.prefix(8))"
        jurisdiction.name = "Jurisdiction-\(UUID().uuidString.prefix(8))"
        jurisdiction.jurisdictionType = .state
        try await jurisdiction.save(on: db)

        let entityType = EntityType()
        entityType.name = "LLC-\(UUID().uuidString.prefix(8))"
        entityType.$jurisdiction.id = jurisdiction.id!
        try await entityType.save(on: db)

        let entity = Entity()
        entity.name = name
        entity.$legalEntityType.id = entityType.id!
        try await entity.save(on: db)
        return entity.id!
    }
}
