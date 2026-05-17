import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorOIDCMiddleware
import Testing

@testable import NavigatorWeb

@Suite("NLF API Tests", .serialized)
struct AppTests {
    @Test("listQuestions returns a successful response for admin")
    func listQuestionsReturnsOkForAdmin() async throws {
        try await withTestDatabaseService { databaseService in
            let handler = try await makeHandler(databaseService: databaseService)
            let output = try await RequestLocals.$userRole.withValue(.admin) {
                try await handler.listQuestions(.init())
            }
            if case .ok = output {
                // pass
            } else {
                Issue.record("Expected ok response from listQuestions for admin")
            }
        }
    }

    @Test("listQuestions returns 403 for non-admin")
    func listQuestionsReturns403ForClient() async throws {
        try await withTestDatabaseService { databaseService in
            let handler = try await makeHandler(databaseService: databaseService)
            let output = try await RequestLocals.$userRole.withValue(.client) {
                try await handler.listQuestions(.init())
            }
            if case .undocumented(let statusCode, _) = output, statusCode == 403 {
                // pass
            } else {
                Issue.record("Expected 403 from listQuestions for client")
            }
        }
    }

    @Test("listPeople returns a successful response for admin")
    func listPeopleReturnsOkForAdmin() async throws {
        try await withTestDatabaseService { databaseService in
            let handler = try await makeHandler(databaseService: databaseService)
            let output = try await RequestLocals.$userRole.withValue(.admin) {
                try await handler.listPeople(.init())
            }
            if case .ok = output {
                // pass
            } else {
                Issue.record("Expected ok response from listPeople for admin")
            }
        }
    }

    @Test("listPeople returns 403 for non-admin")
    func listPeopleReturns403ForClient() async throws {
        try await withTestDatabaseService { databaseService in
            let handler = try await makeHandler(databaseService: databaseService)
            let output = try await RequestLocals.$userRole.withValue(.client) {
                try await handler.listPeople(.init())
            }
            if case .undocumented(let statusCode, _) = output, statusCode == 403 {
                // pass
            } else {
                Issue.record("Expected 403 from listPeople for client")
            }
        }
    }

    @Test("createQuestion returns 403 for non-admin")
    func createQuestionReturns403ForClient() async throws {
        try await withTestDatabaseService { databaseService in
            let handler = try await makeHandler(databaseService: databaseService)
            let input = Operations.createQuestion.Input(
                body: .json(
                    Components.Schemas.Question(
                        id: nil,
                        code: "X1",
                        prompt: "Test?",
                        questionType: .string,
                        helpText: nil,
                        choices: nil,
                        insertedAt: nil,
                        updatedAt: nil
                    )
                )
            )
            let output = try await RequestLocals.$userRole.withValue(.client) {
                try await handler.createQuestion(input)
            }
            if case .undocumented(let statusCode, _) = output, statusCode == 403 {
                // pass
            } else {
                Issue.record("Expected 403 from createQuestion for client")
            }
        }
    }

    @Test("updateQuestion returns 403 for non-admin")
    func updateQuestionReturns403ForClient() async throws {
        try await withTestDatabaseService { databaseService in
            let handler = try await makeHandler(databaseService: databaseService)
            let input = Operations.updateQuestion.Input(
                path: .init(id: UUID()),
                body: .json(
                    Components.Schemas.UpdateQuestionRequest(
                        prompt: nil,
                        questionType: nil,
                        code: nil,
                        helpText: nil,
                        choices: nil
                    )
                )
            )
            let output = try await RequestLocals.$userRole.withValue(.client) {
                try await handler.updateQuestion(input)
            }
            if case .undocumented(let statusCode, _) = output, statusCode == 403 {
                // pass
            } else {
                Issue.record("Expected 403 from updateQuestion for client")
            }
        }
    }

    @Test("deleteQuestion returns 403 for non-admin")
    func deleteQuestionReturns403ForClient() async throws {
        try await withTestDatabaseService { databaseService in
            let handler = try await makeHandler(databaseService: databaseService)
            let input = Operations.deleteQuestion.Input(path: .init(id: UUID()))
            let output = try await RequestLocals.$userRole.withValue(.client) {
                try await handler.deleteQuestion(input)
            }
            if case .undocumented(let statusCode, _) = output, statusCode == 403 {
                // pass
            } else {
                Issue.record("Expected 403 from deleteQuestion for client")
            }
        }
    }

    // MARK: - Helpers

    private func makeHandler(databaseService: DatabaseService) async throws -> APIHandler {
        let db = try await databaseService.db
        return APIHandler(
            db: db,
            databaseService: databaseService,
            emailService: EmailService(),
            storageService: StorageService(bucketURL: ""),
            authMiddleware: AuthMiddleware(db: db),
            mailIngestSecret: "test-secret"
        )
    }
}
