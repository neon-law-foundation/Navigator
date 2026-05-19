import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Tests for the print-friendly project view at /admin/projects/:id/print.
@Suite("Admin: Project print view", .serialized)
struct AdminProjectPrintTests {

    @Test("GET /admin/projects/:id/print renders the project codename and title")
    func printPageRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "print-\(UUID().uuidString.prefix(6))"
            p.title = "Printable Project Title"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(p.id!.uuidString)/print",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(#"data-page="project-print""#))
                    #expect(body.contains(p.codename))
                    #expect(body.contains("Printable Project Title"))
                }
            )
        }
    }

    @Test("print page omits the admin sidebar chrome")
    func noSidebarChrome() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "print-nochrome-\(UUID().uuidString.prefix(6))"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(p.id!.uuidString)/print",
                afterResponse: { res async in
                    let body = res.body.string
                    // AdminSidebar always renders a dashboard link with
                    // this stable attribute. A print page must not.
                    #expect(!body.contains(#"data-section="dashboard""#))
                    // Assignment / upload forms from the show page must
                    // not show up either — print is read-only.
                    #expect(!body.contains(#"name="personId""#))
                    #expect(!body.contains(#"type="file""#))
                }
            )
        }
    }

    @Test("print page lists assigned people")
    func printPageListsPeople() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "print-people-\(UUID().uuidString.prefix(6))"
            try await p.save(on: db)
            let person = Person()
            person.name = "Printed Person"
            person.email = "print-\(UUID().uuidString.prefix(6))@example.com"
            try await person.save(on: db)
            let role = PersonProjectRole()
            role.$person.id = person.id!
            role.$project.id = p.id!
            role.role = .staff
            try await role.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(p.id!.uuidString)/print",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("Printed Person"))
                    #expect(body.contains(#"data-section="people""#))
                }
            )
        }
    }

    @Test("unknown project id returns 404")
    func unknownIdIs404() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects/\(UUID().uuidString)/print",
                afterResponse: { res async in
                    #expect(res.status == .notFound)
                }
            )
        }
    }

    @Test("invalid uuid is a 400")
    func badUuidIs400() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/projects/not-a-uuid/print",
                afterResponse: { res async in
                    #expect(res.status == .badRequest)
                }
            )
        }
    }

    @Test("print page exposes a Print button bound to window.print()")
    func printButtonPresent() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "print-btn-\(UUID().uuidString.prefix(6))"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(p.id!.uuidString)/print",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("window.print()"))
                    #expect(body.contains(#"data-section="print-controls""#))
                }
            )
        }
    }
}
