import FluentKit
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Templates (read-only)", .serialized)
struct AdminTemplatesTests {

    @Test("GET /admin/templates renders the list")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/templates",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">Templates<"))
                }
            )
        }
    }

    @Test("GET /admin/templates/:id shows a seeded template")
    func showSeededTemplate() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let t = try await Template.query(on: db).first()
            try #require(t != nil)
            try await app.testing().test(
                .GET,
                "/admin/templates/\(t!.id!.uuidString)",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(t!.title))
                }
            )
        }
    }
}

@Suite("Admin: Questions", .serialized)
struct AdminQuestionsTests {

    @Test("GET /admin/questions renders the list")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/questions",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">Questions<"))
                }
            )
        }
    }

    @Test("POST /admin/questions creates a row")
    func createQuestion() async throws {
        try await withApp(configure: testConfigure) { app in
            let code = "test-q-\(UUID().uuidString.prefix(6))"
            try await app.testing().test(
                .POST,
                "/admin/questions",
                beforeRequest: { req in
                    try req.content.encode(
                        [
                            "code": code, "prompt": "What is your name?", "questionType": "string",
                            "helpText": "Full legal name.",
                        ],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { _ in }
            )
            let db = try await app.databaseService!.db
            let q = try await Question.query(on: db).filter(\.$code == code).first()
            #expect(q?.prompt == "What is your name?")
            #expect(q?.questionType == .string)
        }
    }

    @Test("POST /admin/questions rejects duplicate code")
    func rejectsDuplicateCode() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let code = "dup-q-\(UUID().uuidString.prefix(6))"
            let q = Question()
            q.code = code
            q.prompt = "P"
            q.questionType = .string
            try await q.save(on: db)
            try await app.testing().test(
                .POST,
                "/admin/questions",
                beforeRequest: { req in
                    try req.content.encode(
                        ["code": code, "prompt": "P", "questionType": "string"],
                        as: .urlEncodedForm
                    )
                },
                afterResponse: { res async in
                    #expect(res.status == .unprocessableEntity)
                    #expect(res.body.string.contains("Code is already in use."))
                }
            )
        }
    }
}

@Suite("Admin: Notations (read-only)", .serialized)
struct AdminNotationsTests {

    @Test("GET /admin/notations renders")
    func indexRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/notations",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains(">Notations<"))
                }
            )
        }
    }
}
