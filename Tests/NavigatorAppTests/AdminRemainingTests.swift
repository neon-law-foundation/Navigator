import FluentKit
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Smoke tests verifying every remaining admin section renders without
/// 500s and exposes its label. Per-resource depth tests live next to the
/// fully-CRUDed resources; this suite catches sidebar wiring regressions.
@Suite("Admin: remaining sections render", .serialized)
struct AdminRemainingTests {

    @Test("each remaining /admin/* section returns 200")
    func everyRemainingSectionRenders() async throws {
        let paths = [
            "/admin/retainers",
            "/admin/disclosures",
            "/admin/credentials",
            "/admin/invoices",
            "/admin/billing-profiles",
            "/admin/mailrooms",
            "/admin/users",
            "/admin/user-role-audit",
            "/admin/share-classes",
            "/admin/share-issuances",
        ]
        try await withApp(configure: testConfigure) { app in
            for path in paths {
                try await app.testing().test(
                    .GET,
                    path,
                    afterResponse: { res async in
                        #expect(res.status == .ok, "GET \(path) should return 200")
                    }
                )
            }
        }
    }

    @Test("POST /admin/credentials creates a row")
    func createCredential() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = try await Person.query(on: db).first()
            let jurisdiction = try await Jurisdiction.query(on: db).first()
            try #require(person != nil && jurisdiction != nil)
            let license = "TEST-\(UUID().uuidString.prefix(6))"
            try await app.testing().test(
                .POST,
                "/admin/credentials",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "personId": person!.id!.uuidString,
                            "jurisdictionId": jurisdiction!.id!.uuidString,
                            "licenseNumber": license,
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let created = try await Credential.query(on: db)
                .filter(\.$licenseNumber == license)
                .first()
            #expect(created != nil)
        }
    }

    @Test("POST /admin/mailrooms creates a row")
    func createMailroom() async throws {
        try await withApp(configure: testConfigure) { app in
            let name = "Test mailroom \(UUID().uuidString.prefix(6))"
            try await app.testing().test(
                .POST,
                "/admin/mailrooms",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "name": name, "mailboxStart": "100", "mailboxEnd": "200",
                            "capacity": "50",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let db = try await app.databaseService!.db
            let created = try await Mailroom.query(on: db).filter(\.$name == name).first()
            #expect(created != nil)
            #expect(created?.mailboxStart == 100)
            #expect(created?.capacity == 50)
        }
    }

    @Test("POST /admin/mailrooms with non-integer range fails validation")
    func mailroomValidation() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .POST,
                "/admin/mailrooms",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "name": "Bad numbers", "mailboxStart": "abc", "mailboxEnd": "xyz",
                            "capacity": "",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    #expect(res.body.string.contains("Mailbox start must be an integer."))
                }
            )
        }
    }
}
