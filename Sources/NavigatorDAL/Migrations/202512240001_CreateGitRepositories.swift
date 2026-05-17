import FluentKit

/// Creates the `git_repositories` table for tracking AWS CodeCommit repositories
/// that store notation templates.
///
/// Each repository is owned by exactly one ``Project`` per AWS account
/// (environment). The `onDelete: .restrict` on `project_id` prevents deleting a
/// project while any repository still points at it. One-repo-per-project-per-
/// account uniqueness is enforced via Fluent's `.unique(on:)` so the rule
/// applies on both SQLite and Postgres.
struct CreateGitRepositories: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(GitRepository.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("aws_account_id", .string, .required)
            .field("aws_region", .string, .required)
            .field("codecommit_repository_id", .string, .required)
            .field("repository_name", .string, .required)
            .field("repository_arn", .string, .required)
            .field("description", .string)
            .field("project_id", .uuid, .required, .references("projects", "id", onDelete: .restrict))
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "codecommit_repository_id")
            .unique(on: "project_id", "aws_account_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(GitRepository.schema).delete()
    }
}
