import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Project Database Operations")
struct ProjectTests {

    @Test("saves and fetches title, status, and projectType fields")
    func testProjectTypeAndStatusFields() async throws {
        try await withDatabase { db in
            let project = Project()
            project.codename = "project-type-test"
            project.title = "Alpha Litigation Matter"
            project.status = .active
            project.projectType = .litigation
            try await project.save(on: db)

            let found = try await Project.find(project.id, on: db)
            #expect(found != nil)
            #expect(found?.title == "Alpha Litigation Matter")
            #expect(found?.status == .active)
            #expect(found?.projectType == .litigation)
        }
    }

    @Test("optional fields are nil when not set")
    func testProjectOptionalFieldsDefaultNil() async throws {
        try await withDatabase { db in
            let project = Project()
            project.codename = "bare-project"
            try await project.save(on: db)

            let found = try await Project.find(project.id, on: db)
            #expect(found != nil)
            #expect(found?.title == nil)
            #expect(found?.status == nil)
            #expect(found?.projectType == nil)
        }
    }
}
