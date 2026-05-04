import FluentKit
import FluentSQL

/// Creates the `templates` table — versioned document definitions that can be
/// assigned to people or entities as a ``Notation``.
///
/// A template captures the markdown source, frontmatter metadata, questionnaire
/// state machine, and workflow state machine for one git commit of a template
/// file. The `code` field is stable across versions and identifies the template
/// family; the `version` field carries the git commit SHA. The composite
/// uniqueness on `(title, git_repository_id)` prevents two distinct templates
/// in the same repo from sharing a title.
struct CreateTemplates: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let respondentType = try await database.enum("respondent_type")
            .case("person")
            .case("entity")
            .case("person_and_entity")
            .create()

        try await database.schema(Template.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("title", .string, .required)
            .field("description", .string, .required)
            .field("respondent_type", respondentType, .required)
            .field("markdown_content", .string, .required)
            .field("frontmatter", .json, .required)
            .field("questionnaire", .json, .required)
            .field("workflow", .json, .required)
            .field("version", .string, .required, .sql(.default("")))
            .field("code", .string)
            .field("git_repository_id", .uuid, .references("git_repositories", "id"))
            .field("owner_id", .uuid, .references("entities", "id"))
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "title", "git_repository_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Template.schema).delete()
        try await database.enum("respondent_type").delete()
    }
}
