import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Notation activity timeline", .serialized)
struct AdminNotationActivityTests {

    @Test("notation show renders the Activity section with the created event")
    func showRendersCreated() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            guard let n = try await Notation.query(on: db).first() else {
                Issue.record("seed pipeline should have created at least one notation")
                return
            }
            try await app.testing().test(
                .GET,
                "/admin/notations/\(n.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Activity<"))
                    #expect(body.contains(#"data-kind="created""#))
                }
            )
        }
    }
}

@Suite("Admin: Retainer activity timeline", .serialized)
struct AdminRetainerActivityTests {

    @Test("retainer show renders the Activity section with the created event")
    func showRendersCreated() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            // Retainers depend on a Notation; create one against the
            // first seeded notation row so we get a valid retainer.
            guard let notation = try await Notation.query(on: db).first() else {
                Issue.record("seed pipeline should have created at least one notation")
                return
            }
            let r = Retainer()
            r.$notation.id = notation.id!
            r.status = .active
            try await r.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/retainers/\(r.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Activity<"))
                    #expect(body.contains(#"data-kind="created""#))
                }
            )
        }
    }
}

@Suite("Admin: Template activity timeline", .serialized)
struct AdminTemplateActivityTests {

    @Test("template show renders the Activity section with the version event")
    func showRendersVersionInserted() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            guard let t = try await Template.query(on: db).first() else {
                Issue.record("seed pipeline should have created at least one template")
                return
            }
            try await app.testing().test(
                .GET,
                "/admin/templates/\(t.id!.uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">Activity<"))
                    #expect(body.contains(#"data-kind="versionInserted""#))
                }
            )
        }
    }
}
