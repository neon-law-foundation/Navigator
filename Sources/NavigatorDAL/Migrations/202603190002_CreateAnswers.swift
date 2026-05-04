import FluentKit
import SQLKit

/// Creates the `answers` table.
///
/// The table records each answer a person (optionally on behalf of an entity) provides
/// to a question. A unique constraint on `(question_id, person_id, value)` prevents
/// duplicate entries for the same respondent and question with the same value.
struct CreateAnswers: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Answer.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("question_id", .uuid, .required, .references(Question.schema, "id"))
            .field("person_id", .uuid, .required, .references(Person.schema, "id"))
            .field("entity_id", .uuid, .references(Entity.schema, "id"))
            // value is stored as JSON/JSONB so it can represent any answer type:
            // plain strings are stored as JSON-quoted strings (e.g. "\"Nick Shook\""),
            // numeric answers as JSON numbers, structured answers (address, person)
            // as JSON objects. AnswerRepository normalises values before writing.
            .field("value", .json, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "question_id", "person_id", "value")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Answer.schema).delete()
    }
}
