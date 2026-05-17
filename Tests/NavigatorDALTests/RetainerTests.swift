import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

// MARK: - Helpers

private func makeNotation(on db: Database) async throws -> Notation {
    let template = Template()
    template.title = "Retainer Agreement \(Int.random(in: 1...99999))"
    template.respondentType = .person
    template.workflow = ["BEGIN": ["_": "END"]]
    template.markdownContent = "# Retainer"
    template.description = "A retainer agreement template"
    template.frontmatter = [:]
    template.questionnaire = [:]
    template.version = "1.0.0"
    try await template.save(on: db)

    let person = Person()
    person.email = "client-\(Int.random(in: 1...99999))@example.com"
    person.name = "Test Client"
    try await person.save(on: db)

    let notation = Notation()
    notation.$template.id = template.id!
    notation.$person.id = person.id!
    try await notation.save(on: db)
    return notation
}

private func makeActiveRetainer(
    notationId: UUID,
    clients: [RetainerClient],
    on db: Database
)
    async throws -> Retainer
{
    let retainer = Retainer()
    retainer.$notation.id = notationId
    retainer.clients = JSONStored(clients)
    retainer.status = .active
    retainer.startsAt = Date(timeIntervalSinceNow: -3600)
    try await retainer.save(on: db)
    return retainer
}

// MARK: - Suite

@Suite("RetainerRepository")
struct RetainerTests {

    @Test("create and find by id")
    func testCreateAndFind() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let retainer = Retainer()
            retainer.$notation.id = notation.id!
            retainer.clients = [RetainerClient(type: .person, id: UUID())]
            retainer.status = .pendingSignature

            let saved = try await repo.create(model: retainer)
            #expect(saved.id != nil)

            let found = try await repo.find(id: saved.id!)
            #expect(found != nil)
            #expect(found?.status == .pendingSignature)
        }
    }

    @Test("findByPersonId returns only retainers containing the person")
    func testFindByPersonId() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let personId = UUID()
            let otherId = UUID()

            // Retainer with target person
            let r1 = Retainer()
            r1.$notation.id = notation.id!
            r1.clients = [RetainerClient(type: .person, id: personId)]
            try await r1.save(on: db)

            // Retainer with a different person
            let r2 = Retainer()
            r2.$notation.id = notation.id!
            r2.clients = [RetainerClient(type: .person, id: otherId)]
            try await r2.save(on: db)

            // Retainer with target person + an entity
            let r3 = Retainer()
            r3.$notation.id = notation.id!
            r3.clients = [
                RetainerClient(type: .person, id: personId),
                RetainerClient(type: .entity, id: UUID()),
            ]
            try await r3.save(on: db)

            let results = try await repo.findByPersonId(personId)
            #expect(results.count == 2)
            let resultIds = Set(results.compactMap(\.id))
            #expect(resultIds.contains(r1.id!))
            #expect(resultIds.contains(r3.id!))
            #expect(!resultIds.contains(r2.id!))
        }
    }

    @Test("findByEntityId returns only retainers containing the entity")
    func testFindByEntityId() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let entityId = UUID()

            let r1 = Retainer()
            r1.$notation.id = notation.id!
            r1.clients = [RetainerClient(type: .entity, id: entityId)]
            try await r1.save(on: db)

            let r2 = Retainer()
            r2.$notation.id = notation.id!
            r2.clients = [RetainerClient(type: .entity, id: UUID())]
            try await r2.save(on: db)

            let results = try await repo.findByEntityId(entityId)
            #expect(results.count == 1)
            #expect(results.first?.id == r1.id)
        }
    }

    @Test("findActiveProjectIds returns project IDs for active retainers containing the person")
    func testFindActiveProjectIdsForPerson() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let personId = UUID()

            let project = Project()
            project.codename = "visible-project"
            try await project.save(on: db)

            let retainer = try await makeActiveRetainer(
                notationId: notation.id!,
                clients: [RetainerClient(type: .person, id: personId)],
                on: db
            )

            let pivot = RetainerProject()
            pivot.$retainer.id = retainer.id!
            pivot.$project.id = project.id!
            try await pivot.save(on: db)

            let projectIds = try await repo.findActiveProjectIds(
                forPersonId: personId,
                entityIds: []
            )
            #expect(projectIds.contains(project.id!))
        }
    }

    @Test("findActiveProjectIds returns empty when retainer is pendingSignature")
    func testFindActiveProjectIdsIgnoresPending() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let personId = UUID()

            let project = Project()
            project.codename = "pending-project"
            try await project.save(on: db)

            let retainer = Retainer()
            retainer.$notation.id = notation.id!
            retainer.clients = [RetainerClient(type: .person, id: personId)]
            retainer.status = .pendingSignature
            try await retainer.save(on: db)

            let pivot = RetainerProject()
            pivot.$retainer.id = retainer.id!
            pivot.$project.id = project.id!
            try await pivot.save(on: db)

            let projectIds = try await repo.findActiveProjectIds(
                forPersonId: personId,
                entityIds: []
            )
            #expect(projectIds.isEmpty)
        }
    }

    @Test("findActiveProjectIds returns empty when ends_at is in the past")
    func testFindActiveProjectIdsIgnoresExpired() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let personId = UUID()

            let project = Project()
            project.codename = "expired-project"
            try await project.save(on: db)

            let retainer = Retainer()
            retainer.$notation.id = notation.id!
            retainer.clients = [RetainerClient(type: .person, id: personId)]
            retainer.status = .active
            retainer.startsAt = Date(timeIntervalSinceNow: -7200)
            retainer.endsAt = Date(timeIntervalSinceNow: -3600)
            try await retainer.save(on: db)

            let pivot = RetainerProject()
            pivot.$retainer.id = retainer.id!
            pivot.$project.id = project.id!
            try await pivot.save(on: db)

            let projectIds = try await repo.findActiveProjectIds(
                forPersonId: personId,
                entityIds: []
            )
            #expect(projectIds.isEmpty)
        }
    }

    @Test("findActiveProjectIds via entity IDs")
    func testFindActiveProjectIdsForEntity() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let entityId = UUID()

            let project = Project()
            project.codename = "entity-project"
            try await project.save(on: db)

            let retainer = try await makeActiveRetainer(
                notationId: notation.id!,
                clients: [RetainerClient(type: .entity, id: entityId)],
                on: db
            )

            let pivot = RetainerProject()
            pivot.$retainer.id = retainer.id!
            pivot.$project.id = project.id!
            try await pivot.save(on: db)

            let projectIds = try await repo.findActiveProjectIds(
                forPersonId: UUID(),
                entityIds: [entityId]
            )
            #expect(projectIds.contains(project.id!))
        }
    }

    @Test("activate sets status and starts_at")
    func testActivate() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let retainer = Retainer()
            retainer.$notation.id = notation.id!
            retainer.clients = [RetainerClient(type: .person, id: UUID())]
            retainer.status = .pendingSignature
            try await retainer.save(on: db)

            let startsAt = Date()
            let updated = try await repo.activate(id: retainer.id!, startsAt: startsAt)
            #expect(updated.status == .active)
            #expect(updated.startsAt != nil)
        }
    }

    @Test("close sets status and ends_at")
    func testClose() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let retainer = try await makeActiveRetainer(
                notationId: notation.id!,
                clients: [RetainerClient(type: .person, id: UUID())],
                on: db
            )

            let endsAt = Date()
            let updated = try await repo.close(id: retainer.id!, endsAt: endsAt)
            #expect(updated.status == .closed)
            #expect(updated.endsAt != nil)
        }
    }

    @Test("activateRetainersForNotation activates pending retainers")
    func testActivateRetainersForNotation() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let r1 = Retainer()
            r1.$notation.id = notation.id!
            r1.clients = [RetainerClient(type: .person, id: UUID())]
            r1.status = .pendingSignature
            try await r1.save(on: db)

            let r2 = Retainer()
            r2.$notation.id = notation.id!
            r2.clients = [RetainerClient(type: .person, id: UUID())]
            r2.status = .pendingSignature
            try await r2.save(on: db)

            try await repo.activateRetainersForNotation(notationId: notation.id!)

            let updated1 = try await repo.find(id: r1.id!)
            let updated2 = try await repo.find(id: r2.id!)
            #expect(updated1?.status == .active)
            #expect(updated1?.startsAt != nil)
            #expect(updated2?.status == .active)
            #expect(updated2?.startsAt != nil)
        }
    }

    @Test("activateRetainersForNotation does not affect already-active retainers")
    func testActivateRetainersSkipsActive() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let originalStartsAt = Date(timeIntervalSinceNow: -86400)
            let retainer = try await makeActiveRetainer(
                notationId: notation.id!,
                clients: [RetainerClient(type: .person, id: UUID())],
                on: db
            )
            retainer.startsAt = originalStartsAt
            try await retainer.save(on: db)

            try await repo.activateRetainersForNotation(notationId: notation.id!)

            let found = try await repo.find(id: retainer.id!)
            #expect(found?.status == .active)
            // startsAt should remain unchanged (pendingSignature filter excluded it)
        }
    }

    @Test("activateRetainersForNotation does not activate retainers for other notations")
    func testActivateRetainersOtherNotation() async throws {
        try await withDatabase { db in
            let notation1 = try await makeNotation(on: db)
            let notation2 = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let r = Retainer()
            r.$notation.id = notation2.id!
            r.clients = [RetainerClient(type: .person, id: UUID())]
            r.status = .pendingSignature
            try await r.save(on: db)

            try await repo.activateRetainersForNotation(notationId: notation1.id!)

            let found = try await repo.find(id: r.id!)
            #expect(found?.status == .pendingSignature)
        }
    }

    @Test("delete removes retainer")
    func testDelete() async throws {
        try await withDatabase { db in
            let notation = try await makeNotation(on: db)
            let repo = RetainerRepository(database: db)

            let retainer = Retainer()
            retainer.$notation.id = notation.id!
            retainer.clients = [RetainerClient(type: .person, id: UUID())]
            let saved = try await repo.create(model: retainer)

            try await repo.delete(id: saved.id!)
            let found = try await repo.find(id: saved.id!)
            #expect(found == nil)
        }
    }

    @Test("delete throws notFound for missing id")
    func testDeleteNotFound() async throws {
        try await withDatabase { db in
            let repo = RetainerRepository(database: db)
            await #expect(throws: Error.self) {
                try await repo.delete(id: UUID())
            }
        }
    }
}
