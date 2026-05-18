import FluentKit
import Foundation
import NavigatorDAL
import NavigatorWeb
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Records every send so tests can assert on what the route handler
/// actually dispatched. Used in place of ``EmailService`` (which would
/// touch SES) on every test app.
private actor RecordingSender: EmailSender {
    private(set) var sent: [OutboundEmail] = []
    var shouldThrow: Error?

    func send(_ message: OutboundEmail) async throws {
        if let err = shouldThrow { throw err }
        sent.append(message)
    }

    func fail(with error: Error) { shouldThrow = error }
    func snapshot() -> [OutboundEmail] { sent }
}

/// `EmailSender` adapter that forwards to a `RecordingSender` actor.
/// `Application.emailSender` requires a non-async value, so the adapter
/// is a small `Sendable` struct wrapping the actor.
private struct RecordingSenderClient: EmailSender {
    let recorder: RecordingSender
    func send(_ message: OutboundEmail) async throws {
        try await recorder.send(message)
    }
}

@Suite("Admin: Messages (outbound)", .serialized)
struct AdminMessagesTests {

    @Test("GET /admin/messages renders the index")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/messages",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">Messages<"))
                }
            )
        }
    }

    @Test("GET /admin/messages/new renders the compose form")
    func newRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/messages/new",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(">New message<"))
                    #expect(body.contains(#"name="to""#))
                    #expect(body.contains(#"name="subject""#))
                    #expect(body.contains(#"name="body""#))
                }
            )
        }
    }

    @Test("POST /admin/messages persists an outbound row and dispatches send")
    func sendPersistsAndDispatches() async throws {
        try await withApp(configure: testConfigure) { app in
            let recorder = RecordingSender()
            app.emailSender = RecordingSenderClient(recorder: recorder)
            try await app.testing().test(
                .POST,
                "/admin/messages",
                beforeRequest: { req in
                    try req.content.encode(
                        ["to": "client@example.com", "subject": "Hello", "body": "Hi there."],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.headers.first(name: .location)?.contains("/admin/messages/") == true)
                }
            )
            let dispatched = await recorder.snapshot()
            #expect(dispatched.count == 1)
            #expect(dispatched.first?.to == "client@example.com")
            #expect(dispatched.first?.from == "support@neonlaw.org")
            #expect(dispatched.first?.subject == "Hello")
            let db = try await app.databaseService!.db
            let persisted = try await EmailMessage.query(on: db)
                .filter(\.$toAddress == "client@example.com")
                .first()
            #expect(persisted != nil)
            #expect(persisted?.direction == .outbound)
        }
    }

    @Test("POST /admin/messages re-renders with errors on missing fields")
    func validationFailsOnMissingFields() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .POST,
                "/admin/messages",
                beforeRequest: { req in
                    try req.content.encode(
                        ["to": "", "subject": "", "body": ""],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    let body = res.body.string
                    #expect(body.contains("Recipient is required."))
                    #expect(body.contains("Subject is required."))
                    #expect(body.contains("Body is required."))
                }
            )
        }
    }

    @Test("POST /admin/messages keeps the persisted row on send failure")
    func failedSendKeepsRow() async throws {
        try await withApp(configure: testConfigure) { app in
            let recorder = RecordingSender()
            await recorder.fail(with: TestSendError.boom)
            app.emailSender = RecordingSenderClient(recorder: recorder)
            try await app.testing().test(
                .POST,
                "/admin/messages",
                beforeRequest: { req in
                    try req.content.encode(
                        ["to": "fail@example.com", "subject": "Boom", "body": "Still saved."],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    let location = res.headers.first(name: .location) ?? ""
                    #expect(location.contains("/admin/messages/"))
                    #expect(location.contains("send_error="))
                }
            )
            let db = try await app.databaseService!.db
            let persisted = try await EmailMessage.query(on: db)
                .filter(\.$toAddress == "fail@example.com")
                .first()
            #expect(persisted != nil)
        }
    }

    @Test("/admin/inbox filters out outbound rows")
    func inboxExcludesOutbound() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            // Seed one outbound row directly via the repository.
            let saved = try await EmailMessageRepository(database: db).createOutbound(
                to: "client@example.com",
                from: "support@neonlaw.org",
                subject: "Unique-subject-\(UUID().uuidString.prefix(6))",
                textBody: "Body."
            )
            try await app.testing().test(
                .GET,
                "/admin/inbox",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(!body.contains(saved.subject))
                }
            )
            try await app.testing().test(
                .GET,
                "/admin/messages",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(saved.subject))
                }
            )
        }
    }
}

private enum TestSendError: Error {
    case boom
}
