import FluentKit
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: People", .serialized)
struct AdminPeopleTests {

    @Test("GET /admin/people lists the people table")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/people",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">People<"))
                    #expect(res.body.string.contains("New person"))
                }
            )
        }
    }

    @Test("GET /admin/people/new renders an empty form")
    func newFormRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/people/new",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">New person<"))
                    #expect(body.contains(#"name="name""#))
                    #expect(body.contains(#"name="email""#))
                    #expect(body.contains(#"type="email""#))
                }
            )
        }
    }

    @Test("POST /admin/people creates a row")
    func createPerson() async throws {
        try await withApp(configure: testConfigure) { app in
            let email = "create-\(UUID().uuidString.prefix(8))@example.com"
            try await app.testing().test(
                .POST,
                "/admin/people",
                beforeRequest: { req in
                    try req.content.encode(
                        ["name": "Alice Creator", "email": email],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/people") == true)
                }
            )
            let db = try await app.databaseService!.db
            let person = try await PersonRepository(database: db).findByEmail(email)
            #expect(person?.name == "Alice Creator")
        }
    }

    @Test("POST /admin/people rejects missing fields")
    func createValidates() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .POST,
                "/admin/people",
                beforeRequest: { req in
                    try req.content.encode(["name": "", "email": ""], as: .urlEncodedForm)
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    let body = res.body.string
                    #expect(body.contains("Name is required."))
                    #expect(body.contains("Email is required."))
                }
            )
        }
    }

    @Test("POST /admin/people rejects a duplicate email")
    func createRejectsDuplicateEmail() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let email = "dup-\(UUID().uuidString.prefix(8))@example.com"
            let existing = Person()
            existing.name = "Existing"
            existing.email = email
            try await existing.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/people",
                beforeRequest: { req in
                    try req.content.encode(
                        ["name": "Imposter", "email": email],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    #expect(res.body.string.contains("Email is already in use."))
                }
            )
        }
    }

    @Test("GET /admin/people/:id renders the show page")
    func showRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = Person()
            person.name = "Shown Person"
            person.email = "show-\(UUID().uuidString.prefix(8))@example.com"
            try await person.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/people/\(person.id!.uuidString)",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Shown Person"))
                }
            )
        }
    }

    @Test("PATCH updates and DELETE removes")
    func updateAndDelete() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = Person()
            person.name = "Before"
            person.email = "update-\(UUID().uuidString.prefix(8))@example.com"
            try await person.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/people/\(person.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(
                        ["_method": "PATCH", "name": "After", "email": person.email],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let updated = try await PersonRepository(database: db).find(id: person.id!)
            #expect(updated?.name == "After")
            try await app.testing().test(
                .POST,
                "/admin/people/\(person.id!.uuidString)",
                beforeRequest: { req in
                    try req.content.encode(["_method": "DELETE"], as: .urlEncodedForm)
                },
                afterResponse: { _ in }
            )
            let gone = try await PersonRepository(database: db).find(id: person.id!)
            #expect(gone == nil)
        }
    }
}
