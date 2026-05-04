import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import Testing
import Vapor

@Suite("Answer and Notation Integration")
struct AnswerNotationIntegrationTests {

    @Test("Answer findOrCreate deduplicates by (question_id, person_id, value)")
    func testAnswerFindOrCreateDeduplicates() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(on: app.db, logger: app.logger)

            let question = try await Question.query(on: app.db).first()
            let questionID = try #require(question?.id)

            let person = try await Person.query(on: app.db).first()
            let personID = try #require(person?.id)

            let repo = AnswerRepository()
            let a1 = try await repo.findOrCreate(
                questionID: questionID,
                personID: personID,
                entityID: nil,
                value: "hello",
                on: app.db
            )
            let a2 = try await repo.findOrCreate(
                questionID: questionID,
                personID: personID,
                entityID: nil,
                value: "hello",
                on: app.db
            )
            #expect(try a1.requireID() == a2.requireID())

            let a3 = try await repo.findOrCreate(
                questionID: questionID,
                personID: personID,
                entityID: nil,
                value: "world",
                on: app.db
            )
            #expect(try a3.requireID() != a1.requireID())
        }
    }

    @Test("Notation stores answers and rendered_content")
    func testNotationStoresAnswersAndRenderedContent() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(on: app.db, logger: app.logger)

            let template = try await Template.query(on: app.db).first()
            let templateID = try #require(template?.id)

            let person = try await Person.query(on: app.db).first()
            let personID = try #require(person?.id)

            let question = try await Question.query(on: app.db).first()
            let questionID = try #require(question?.id)

            let answerRepo = AnswerRepository()
            let answer = try await answerRepo.findOrCreate(
                questionID: questionID,
                personID: personID,
                entityID: nil,
                value: "Nick Shook",
                on: app.db
            )
            let answerID = try answer.requireID()

            let notation = Notation()
            notation.$template.id = templateID
            notation.$person.id = personID
            notation.stateHistory = []
            notation.answers = [question?.code ?? "test_code": answerID]
            notation.renderedContent = "Hello, World!"
            try await notation.save(on: app.db)

            let notationID = try notation.requireID()
            let loaded = try await Notation.find(notationID, on: app.db)
            #expect(loaded?.answers[question?.code ?? "test_code"] == answerID)
            #expect(loaded?.renderedContent == "Hello, World!")
        }
    }

    @Test("Answer find returns existing answer by (question_id, person_id)")
    func testAnswerFind() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(on: app.db, logger: app.logger)

            // Use a question code that is not pre-seeded in Answer.yaml
            // so the initial find returns nil as expected.
            let question = try await Question.query(on: app.db)
                .filter(\.$code == "personal_address")
                .first()
            let questionID = try #require(question?.id)

            let person = try await Person.query(on: app.db).first()
            let personID = try #require(person?.id)

            let repo = AnswerRepository()

            let notFound = try await repo.find(
                questionID: questionID,
                personID: personID,
                entityID: nil,
                on: app.db
            )
            #expect(notFound == nil)

            _ = try await repo.findOrCreate(
                questionID: questionID,
                personID: personID,
                entityID: nil,
                value: "123 Main St",
                on: app.db
            )

            let found = try await repo.find(
                questionID: questionID,
                personID: personID,
                entityID: nil,
                on: app.db
            )
            // Value is stored as a JSON-encoded string, so "123 Main St" → "\"123 Main St\""
            #expect(found != nil)
            #expect(found?.value == AnswerRepository.normalizeToJSON("123 Main St"))
        }
    }
}
