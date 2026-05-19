import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Markup-contract tests for the Alpine.js keyboard navigation layer.
///
/// These tests verify the contract the in-browser handler depends on:
/// the Alpine CDN script tag is present, the admin wrapper carries the
/// `x-data="adminShortcuts"` Alpine component, list rows expose
/// `data-row-href`, and the primary "New …" CTA carries
/// `data-shortcut="new"`. Actual keyboard behavior runs in the browser
/// and is covered by browser automation rather than this suite.
@Suite("Admin: Alpine keyboard navigation markup", .serialized)
struct AdminAlpineKeyboardTests {

    @Test("admin layout loads Alpine from the CDN with defer")
    func layoutLoadsAlpineCdn() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains("https://unpkg.com/alpinejs@3.14.1/dist/cdn.min.js"))
                    #expect(body.contains(#"defer="defer""#))
                }
            )
        }
    }

    @Test("admin layout wraps the body in an Alpine component")
    func layoutDefinesAdminShortcutsComponent() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"x-data="adminShortcuts""#))
                    // The inline script defining the component should
                    // be present in the rendered shell.
                    #expect(body.contains("Alpine.data('adminShortcuts'"))
                }
            )
        }
    }

    @Test("projects index rows expose data-row-href")
    func projectsRowsExposeRowHref() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let project = Project()
            project.codename = "alpine-projects-\(UUID().uuidString.prefix(6))"
            try await project.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/projects",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(
                        body.contains(
                            #"data-row-href="/admin/projects/\#(project.id?.uuidString ?? "")""#
                        )
                    )
                }
            )
        }
    }

    @Test("people index rows expose data-row-href")
    func peopleRowsExposeRowHref() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = Person()
            person.name = "Alpine Person"
            person.email = "alpine-\(UUID().uuidString.prefix(8))@example.com"
            try await person.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/people",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(
                        body.contains(
                            #"data-row-href="/admin/people/\#(person.id?.uuidString ?? "")""#
                        )
                    )
                }
            )
        }
    }

    @Test("entities index rows expose data-row-href")
    func entitiesRowsExposeRowHref() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            guard let type = try await EntityType.query(on: db).first() else {
                Issue.record("Expected a seeded EntityType")
                return
            }
            let entity = Entity()
            entity.name = "Alpine Entity \(UUID().uuidString.prefix(6))"
            entity.$legalEntityType.id = type.id!
            try await entity.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/entities",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(
                        body.contains(
                            #"data-row-href="/admin/entities/\#(entity.id?.uuidString ?? "")""#
                        )
                    )
                }
            )
        }
    }

    @Test("inbox index rows expose data-row-href")
    func inboxRowsExposeRowHref() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let blob = Blob()
            blob.objectStorageUrl =
                "s3://test/alpine-inbox-\(UUID().uuidString).eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let message = EmailMessage()
            message.messageId = "<alpine-\(UUID().uuidString)@example.com>"
            message.threadId = message.messageId
            message.fromAddress = "outside@example.com"
            message.fromName = "Outside"
            message.toAddress = "support@example.com"
            message.subject = "Alpine inbox keyboard test"
            message.receivedAt = Date()
            message.$rawBlob.id = blob.id!
            message.spamVerdict = "PASS"
            message.virusVerdict = "PASS"
            message.dkimVerdict = "PASS"
            message.dmarcVerdict = "PASS"
            try await message.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/inbox",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(
                        body.contains(
                            #"data-row-href="/admin/inbox/\#(message.id?.uuidString ?? "")""#
                        )
                    )
                }
            )
        }
    }

    @Test("New CTA buttons advertise the Shift+N shortcut")
    func newCtasMarkShiftN() async throws {
        try await withApp(configure: testConfigure) { app in
            for path in [
                "/admin/projects", "/admin/people", "/admin/entities",
            ] {
                try await app.testing().test(
                    .GET,
                    path,
                    afterResponse: { res async in
                        #expect(res.body.string.contains(#"data-shortcut="new""#))
                    }
                )
            }
        }
    }
}
