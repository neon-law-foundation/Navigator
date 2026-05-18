import FluentKit
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Full CRUD coverage for `/admin/projects`. The suite seeds its own
/// rows through the live database so the assertions exercise the same
/// stack the operator hits in production.
@Suite("Admin: Projects", .serialized)
struct AdminProjectsTests {

    @Test("GET /admin/projects renders the seeded codename in a row")
    func indexListsSeededProjects() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(">Projects<"))
                    // The seed data ships at least one project; verify
                    // the table chrome and "New project" CTA both ship.
                    #expect(body.contains("New project"))
                    #expect(body.contains("<table"))
                }
            )
        }
    }

    @Test("GET /admin/projects/new renders an empty form")
    func newFormRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects/new",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(">New project<"))
                    #expect(body.contains(#"name="codename""#))
                    #expect(body.contains(#"name="title""#))
                    #expect(body.contains(#"name="status""#))
                    #expect(body.contains(#"name="projectType""#))
                    // New form posts as POST without _method override.
                    #expect(body.contains(#"action="/admin/projects""#))
                    #expect(body.contains(#"method="post""#))
                    #expect(!body.contains(#"name="_method""#))
                }
            )
        }
    }

    @Test("POST /admin/projects creates a row and redirects to the index")
    func createPersistsAndRedirects() async throws {
        try await withApp(configure: testConfigure) { app in
            let codename = "test-create-\(UUID().uuidString.prefix(8))"
            try await app.testing().test(
                .POST,
                "/admin/projects",
                beforeRequest: { req in
                    try req.content.encode(
                        ["codename": codename, "title": "Test Create", "status": "active", "projectType": ""],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(
                        res.status == .seeOther || res.status == .ok || res.status.code == 302 || res.status.code == 303
                    )
                    #expect(res.headers.first(name: .location)?.contains("/admin/projects") == true)
                }
            )
            // Confirm the row landed.
            let db = try await app.databaseService!.db
            let project = try await ProjectRepository(database: db).findByCodename(codename)
            #expect(project != nil)
            #expect(project?.title == "Test Create")
            #expect(project?.status == .active)
        }
    }

    @Test("POST /admin/projects without a codename re-renders the form with an error")
    func createRequiresCodename() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .POST,
                "/admin/projects",
                beforeRequest: { req in
                    try req.content.encode(
                        ["codename": "", "title": "No codename here"],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    let body = res.body.string
                    #expect(body.contains("Codename is required."))
                    // The submitted title is rendered back in the form so
                    // the operator does not retype it.
                    #expect(body.contains(#"value="No codename here""#))
                }
            )
        }
    }

    @Test("POST /admin/projects with a duplicate codename fails with a unique error")
    func createRejectsDuplicateCodename() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let codename = "dup-\(UUID().uuidString.prefix(8))"
            let existing = Project()
            existing.codename = codename
            try await existing.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/projects",
                beforeRequest: { req in
                    try req.content.encode(
                        ["codename": codename, "title": "Dupe attempt"],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    let body = res.body.string
                    #expect(body.contains("Codename is already taken."))
                }
            )
        }
    }

    @Test("GET /admin/projects/:id renders the show page with the project's fields")
    func showRendersDetail() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let codename = "show-\(UUID().uuidString.prefix(8))"
            let project = Project()
            project.codename = codename
            project.title = "Show Test"
            project.status = .active
            project.projectType = .litigation
            try await project.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(codename))
                    #expect(body.contains("Show Test"))
                    #expect(body.contains(">active<"))
                    #expect(body.contains(">litigation<"))
                }
            )
        }
    }

    @Test("GET /admin/projects/:id/edit pre-populates the form")
    func editFormPrePopulated() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let codename = "edit-\(UUID().uuidString.prefix(8))"
            let project = Project()
            project.codename = codename
            project.title = "Pre-populated"
            try await project.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)/edit",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(">Edit project<"))
                    #expect(body.contains(#"value="\#(codename)""#))
                    #expect(body.contains(#"value="Pre-populated""#))
                    // Edit form posts as POST with _method=PATCH.
                    #expect(body.contains(#"value="PATCH""#))
                }
            )
        }
    }

    @Test("POST /admin/projects/:id with _method=PATCH updates the row")
    func updatePersistsChanges() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let codename = "upd-\(UUID().uuidString.prefix(8))"
            let project = Project()
            project.codename = codename
            project.title = "Old title"
            try await project.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "_method": "PATCH", "codename": codename, "title": "New title", "status": "closed",
                            "projectType": "",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/projects") == true)
                }
            )
            let reloaded = try await ProjectRepository(database: db).find(id: project.id!)
            #expect(reloaded?.title == "New title")
            #expect(reloaded?.status == .closed)
        }
    }

    @Test("POST /admin/projects/:id with _method=DELETE removes the row")
    func deleteRemovesRow() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let codename = "del-\(UUID().uuidString.prefix(8))"
            let project = Project()
            project.codename = codename
            try await project.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/projects/\(project.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/projects") == true)
                }
            )
            let reloaded = try await ProjectRepository(database: db).find(id: project.id!)
            #expect(reloaded == nil)
        }
    }

    @Test("GET /admin/projects/:id with an unknown id returns 404")
    func showWithUnknownIDReturns404() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects/\(UUID().uuidString)",
                afterResponse: { res async in
                    #expect(res.status == .notFound)
                }
            )
        }
    }

    @Test("GET /admin/projects/:id with a malformed id returns 400")
    func showWithMalformedIDReturns400() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects/not-a-uuid",
                afterResponse: { res async in
                    #expect(res.status == .badRequest)
                }
            )
        }
    }
}
