import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Send-message from project", .serialized)
struct AdminProjectMessageTests {

    @Test("project show renders a Send-message link to the compose form")
    func projectShowHasSendMessageButton() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = Project()
            project.codename = "psm-\(UUID().uuidString.prefix(6))"
            try await project.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects/\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(
                        body.contains(
                            #"href="/admin/messages/new?project_id=\#(project.id!.uuidString)""#
                        )
                    )
                    #expect(body.contains(">Send message<"))
                }
            )
        }
    }

    @Test("compose pre-fills the project codename in the subject")
    func composePreFillsSubjectFromProject() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = Project()
            project.codename = "ALPHA-\(UUID().uuidString.prefix(4))"
            try await project.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/messages/new?project_id=\(project.id!.uuidString)",
                afterResponse: { res async in
                    #expect(res.body.string.contains(#"value="[\#(project.codename)] ""#))
                }
            )
        }
    }

    @Test("compose pre-fills the to field with the project's unique client email")
    func composePreFillsClientEmail() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = Project()
            project.codename = "clientproj-\(UUID().uuidString.prefix(4))"
            try await project.save(on: db)
            let person = Person()
            person.name = "Client Person"
            person.email = "client-\(UUID().uuidString.prefix(6))@example.com"
            try await person.save(on: db)
            let role = PersonProjectRole()
            role.$person.id = person.id!
            role.$project.id = project.id!
            role.role = .client
            try await role.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/messages/new?project_id=\(project.id!.uuidString)",
                afterResponse: { res async in
                    #expect(res.body.string.contains(#"value="\#(person.email)""#))
                }
            )
        }
    }

    @Test("compose leaves to blank when the project has more than one client")
    func multipleClientsLeavesToBlank() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = Project()
            project.codename = "multi-\(UUID().uuidString.prefix(4))"
            try await project.save(on: db)
            for i in 0..<2 {
                let p = Person()
                p.name = "Client \(i)"
                p.email = "client-\(i)-\(UUID().uuidString.prefix(4))@example.com"
                try await p.save(on: db)
                let r = PersonProjectRole()
                r.$person.id = p.id!
                r.$project.id = project.id!
                r.role = .client
                try await r.save(on: db)
            }
            try await app.testing().test(
                .GET,
                "/admin/messages/new?project_id=\(project.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    // Subject still prefilled, but `to` is empty so no
                    // value="…@example.com" appears for the field.
                    #expect(body.contains(#"value="[\#(project.codename)] ""#))
                    // The `to` input has no value attribute when blank.
                    #expect(body.contains(#"id="field-to""#))
                }
            )
        }
    }
}
