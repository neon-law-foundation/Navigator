import FluentKit

/// Creates the `questions` table backing ``Question`` and the `question_type`
/// Postgres enum used for the `question_type` column.
///
/// The enum lists every case in ``QuestionType``; SQLite (used in tests) maps
/// the column to TEXT and ignores the enum type, so values are written as raw
/// strings on that backend.
struct CreateQuestions: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let questionType = try await database.enum("question_type")
            .case("string")
            .case("text")
            .case("date")
            .case("datetime")
            .case("number")
            .case("yes_no")
            .case("radio")
            .case("select")
            .case("multi_select")
            .case("secret")
            .case("phone")
            .case("email")
            .case("ssn")
            .case("ein")
            .case("file")
            .case("person")
            .case("address")
            .case("org")
            .create()

        try await database.schema(Question.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("prompt", .string, .required)
            .field("question_type", questionType, .required)
            .field("code", .string, .required)
            .field("help_text", .string)
            .field("choices", .dictionary)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "code")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Question.schema).delete()
        try await database.enum("question_type").delete()
    }
}
