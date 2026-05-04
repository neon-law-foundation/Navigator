import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("RetainerProjectRepository")
struct RetainerProjectTests {

    private func makeNotationAndRetainer(on db: Database) async throws -> Retainer {
        let template = Template()
        template.title = "RP Test Template \(Int.random(in: 1...99999))"
        template.respondentType = .person
        template.workflow = ["BEGIN": ["_": "END"]]
        template.markdownContent = "# RP Template"
        template.description = "A retainer project test template"
        template.frontmatter = [:]
        template.questionnaire = [:]
        template.version = "1.0.0"
        try await template.save(on: db)

        let person = Person()
        person.email = "rp-\(Int.random(in: 1...99999))@example.com"
        person.name = "RP Client"
        try await person.save(on: db)

        let notation = Notation()
        notation.$template.id = template.id!
        notation.$person.id = person.id!
        try await notation.save(on: db)

        let retainer = Retainer()
        retainer.$notation.id = notation.id!
        retainer.clients = [RetainerClient(type: .person, id: person.id!)]
        try await retainer.save(on: db)
        return retainer
    }

    private func makeProject(codename: String, on db: Database) async throws -> Project {
        let project = Project()
        project.codename = codename
        try await project.save(on: db)
        return project
    }

    @Test("create and find by id")
    func testCreateAndFind() async throws {
        try await withDatabase { db in
            let retainer = try await makeNotationAndRetainer(on: db)
            let project = try await makeProject(codename: "rp-test-\(Int.random(in: 1...99999))", on: db)
            let repo = RetainerProjectRepository(database: db)

            let pivot = RetainerProject()
            pivot.$retainer.id = retainer.id!
            pivot.$project.id = project.id!

            let saved = try await repo.create(model: pivot)
            #expect(saved.id != nil)

            let found = try await repo.find(id: saved.id!)
            #expect(found != nil)
            #expect(found?.$retainer.id == retainer.id)
            #expect(found?.$project.id == project.id)
        }
    }

    @Test("findByRetainer returns all pivots for that retainer")
    func testFindByRetainer() async throws {
        try await withDatabase { db in
            let retainer = try await makeNotationAndRetainer(on: db)
            let p1 = try await makeProject(codename: "rp-proj-a-\(Int.random(in: 1...99999))", on: db)
            let p2 = try await makeProject(codename: "rp-proj-b-\(Int.random(in: 1...99999))", on: db)
            let repo = RetainerProjectRepository(database: db)

            let pivot1 = RetainerProject()
            pivot1.$retainer.id = retainer.id!
            pivot1.$project.id = p1.id!
            try await pivot1.save(on: db)

            let pivot2 = RetainerProject()
            pivot2.$retainer.id = retainer.id!
            pivot2.$project.id = p2.id!
            try await pivot2.save(on: db)

            let pivots = try await repo.findByRetainer(retainerId: retainer.id!)
            #expect(pivots.count == 2)
        }
    }

    @Test("findByProject returns all pivots for that project")
    func testFindByProject() async throws {
        try await withDatabase { db in
            let r1 = try await makeNotationAndRetainer(on: db)
            let r2 = try await makeNotationAndRetainer(on: db)
            let project = try await makeProject(codename: "shared-\(Int.random(in: 1...99999))", on: db)
            let repo = RetainerProjectRepository(database: db)

            let pv1 = RetainerProject()
            pv1.$retainer.id = r1.id!
            pv1.$project.id = project.id!
            try await pv1.save(on: db)

            let pv2 = RetainerProject()
            pv2.$retainer.id = r2.id!
            pv2.$project.id = project.id!
            try await pv2.save(on: db)

            let pivots = try await repo.findByProject(projectId: project.id!)
            #expect(pivots.count == 2)
        }
    }

    @Test("composite unique constraint prevents duplicate (retainer, project) pairs")
    func testCompositeUnique() async throws {
        try await withDatabase { db in
            let retainer = try await makeNotationAndRetainer(on: db)
            let project = try await makeProject(codename: "unique-\(Int.random(in: 1...99999))", on: db)

            let pv1 = RetainerProject()
            pv1.$retainer.id = retainer.id!
            pv1.$project.id = project.id!
            try await pv1.save(on: db)

            let pv2 = RetainerProject()
            pv2.$retainer.id = retainer.id!
            pv2.$project.id = project.id!

            await #expect(throws: Error.self) {
                try await pv2.save(on: db)
            }
        }
    }

    @Test("delete removes pivot")
    func testDelete() async throws {
        try await withDatabase { db in
            let retainer = try await makeNotationAndRetainer(on: db)
            let project = try await makeProject(codename: "del-\(Int.random(in: 1...99999))", on: db)
            let repo = RetainerProjectRepository(database: db)

            let pivot = RetainerProject()
            pivot.$retainer.id = retainer.id!
            pivot.$project.id = project.id!
            let saved = try await repo.create(model: pivot)

            try await repo.delete(id: saved.id!)
            let found = try await repo.find(id: saved.id!)
            #expect(found == nil)
        }
    }

    @Test("delete throws notFound for missing id")
    func testDeleteNotFound() async throws {
        try await withDatabase { db in
            let repo = RetainerProjectRepository(database: db)
            await #expect(throws: Error.self) {
                try await repo.delete(id: UUID())
            }
        }
    }
}
