import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Add letter", .serialized)
struct AdminLetterTests {

    @Test("GET /admin/mailroom renders a New-letter button")
    func adminMailroomHasNewLetterButton() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/mailroom",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"href="/admin/mailroom/letters/new""#))
                    #expect(body.contains(">New letter<"))
                }
            )
        }
    }

    @Test("GET /portal/mailroom does NOT render the New-letter button")
    func portalMailroomHasNoNewLetterButton() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/portal/mailroom",
                afterResponse: { res async in
                    #expect(!res.body.string.contains("/admin/mailroom/letters/new"))
                }
            )
        }
    }

    @Test("GET /admin/mailroom/letters/new renders the compose form")
    func newFormRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/mailroom/letters/new",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(">New letter<"))
                    #expect(body.contains(#"name="mailroomId""#))
                    #expect(body.contains(#"name="sender""#))
                    #expect(body.contains(#"name="subject""#))
                    #expect(body.contains(#"name="receivedAt""#))
                }
            )
        }
    }

    @Test("POST /admin/mailroom/letters persists a row and redirects to the mailroom")
    func postPersistsLetter() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let mailroom = try await Mailroom.query(on: db).first()
            try #require(mailroom != nil)
            let subject = "Test letter \(UUID().uuidString.prefix(6))"
            try await app.testing().test(
                .POST,
                "/admin/mailroom/letters",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "mailroomId": mailroom!.id!.uuidString,
                            "mailboxNumber": "1234",
                            "sender": "Test Sender",
                            "subject": subject,
                            "receivedAt": "2026-05-18",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location) == "/admin/mailroom")
                }
            )
            let saved = try await Letter.query(on: db).filter(\.$subject == subject).first()
            #expect(saved?.sender == "Test Sender")
            #expect(saved?.mailboxNumber == 1234)
            #expect(saved?.receivedAt != nil)
        }
    }

    @Test("POST without a mailroom id fails validation")
    func rejectsMissingMailroom() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .POST,
                "/admin/mailroom/letters",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "mailroomId": "",
                            "sender": "X",
                            "subject": "Y",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    #expect(res.body.string.contains("Pick a mailroom."))
                }
            )
        }
    }

    @Test("POST with non-integer mailbox number fails validation")
    func rejectsNonIntegerMailbox() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let mailroom = try await Mailroom.query(on: db).first()
            try #require(mailroom != nil)
            try await app.testing().test(
                .POST,
                "/admin/mailroom/letters",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "mailroomId": mailroom!.id!.uuidString,
                            "mailboxNumber": "abc",
                            "sender": "X",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    #expect(res.body.string.contains("Mailbox number must be an integer."))
                }
            )
        }
    }
}
