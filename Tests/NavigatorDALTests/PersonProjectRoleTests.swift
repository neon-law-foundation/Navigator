import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("PersonProjectRole Database Operations")
struct PersonProjectRoleTests {

    @Test("Can create a PersonProjectRole")
    func testCreatePersonProjectRole() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "ppr-create@example.com"
            person.name = "PPR Create Person"
            try await person.save(on: db)

            let project = Project()
            project.codename = "ppr-create-project"
            try await project.save(on: db)

            let repo = PersonProjectRoleRepository(database: db)
            let membership = PersonProjectRole()
            membership.$person.id = person.id!
            membership.$project.id = project.id!
            membership.role = .client

            let created = try await repo.create(model: membership)

            #expect(created.id != nil)
            #expect(created.$person.id == person.id!)
            #expect(created.$project.id == project.id!)
            #expect(created.role == .client)
            #expect(created.insertedAt != nil)
            #expect(created.updatedAt != nil)
        }
    }

    @Test("Composite unique constraint prevents duplicate person-project pair")
    func testUniqueConstraint() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "ppr-unique@example.com"
            person.name = "PPR Unique Person"
            try await person.save(on: db)

            let project = Project()
            project.codename = "ppr-unique-project"
            try await project.save(on: db)

            let first = PersonProjectRole()
            first.$person.id = person.id!
            first.$project.id = project.id!
            first.role = .staff
            try await first.save(on: db)

            let duplicate = PersonProjectRole()
            duplicate.$person.id = person.id!
            duplicate.$project.id = project.id!
            duplicate.role = .client

            await #expect(throws: Error.self) {
                try await duplicate.save(on: db)
            }
        }
    }

    @Test("findByPerson returns all roles for a person")
    func testFindByPerson() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "ppr-byperson@example.com"
            person.name = "PPR ByPerson"
            try await person.save(on: db)

            let project1 = Project()
            project1.codename = "ppr-byperson-project-1"
            try await project1.save(on: db)

            let project2 = Project()
            project2.codename = "ppr-byperson-project-2"
            try await project2.save(on: db)

            let role1 = PersonProjectRole()
            role1.$person.id = person.id!
            role1.$project.id = project1.id!
            role1.role = .staff
            try await role1.save(on: db)

            let role2 = PersonProjectRole()
            role2.$person.id = person.id!
            role2.$project.id = project2.id!
            role2.role = .client
            try await role2.save(on: db)

            let repo = PersonProjectRoleRepository(database: db)
            let roles = try await repo.findByPerson(personId: person.id!)

            #expect(roles.count == 2)
        }
    }

    @Test("findProjectIds returns project IDs for a person")
    func testFindProjectIds() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "ppr-projectids@example.com"
            person.name = "PPR ProjectIds"
            try await person.save(on: db)

            let project1 = Project()
            project1.codename = "ppr-projectids-project-1"
            try await project1.save(on: db)

            let project2 = Project()
            project2.codename = "ppr-projectids-project-2"
            try await project2.save(on: db)

            let role1 = PersonProjectRole()
            role1.$person.id = person.id!
            role1.$project.id = project1.id!
            role1.role = .staff
            try await role1.save(on: db)

            let role2 = PersonProjectRole()
            role2.$person.id = person.id!
            role2.$project.id = project2.id!
            role2.role = .client
            try await role2.save(on: db)

            let repo = PersonProjectRoleRepository(database: db)
            let projectIds = try await repo.findProjectIds(forPersonId: person.id!)

            #expect(projectIds.count == 2)
            #expect(projectIds.contains(project1.id!))
            #expect(projectIds.contains(project2.id!))
        }
    }

    @Test("findByProject returns all roles for a project")
    func testFindByProject() async throws {
        try await withDatabase { db in
            let person1 = Person()
            person1.email = "ppr-byproject-1@example.com"
            person1.name = "PPR ByProject Person One"
            try await person1.save(on: db)

            let person2 = Person()
            person2.email = "ppr-byproject-2@example.com"
            person2.name = "PPR ByProject Person Two"
            try await person2.save(on: db)

            let project = Project()
            project.codename = "ppr-byproject-project"
            try await project.save(on: db)

            let role1 = PersonProjectRole()
            role1.$person.id = person1.id!
            role1.$project.id = project.id!
            role1.role = .staff
            try await role1.save(on: db)

            let role2 = PersonProjectRole()
            role2.$person.id = person2.id!
            role2.$project.id = project.id!
            role2.role = .client
            try await role2.save(on: db)

            let repo = PersonProjectRoleRepository(database: db)
            let roles = try await repo.findByProject(projectId: project.id!)

            #expect(roles.count == 2)
        }
    }

    @Test("findProjectIds returns empty array for person with no memberships")
    func testFindProjectIdsEmpty() async throws {
        try await withDatabase { db in
            let person = Person()
            person.email = "ppr-empty@example.com"
            person.name = "PPR Empty Person"
            try await person.save(on: db)

            let repo = PersonProjectRoleRepository(database: db)
            let projectIds = try await repo.findProjectIds(forPersonId: person.id!)

            #expect(projectIds.isEmpty)
        }
    }
}
