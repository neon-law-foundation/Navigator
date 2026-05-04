import FluentKit
import SQLKit

/// Creates the `git_repositories` table for tracking AWS CodeCommit repositories
/// that store notation templates.
///
/// Each repository is owned by exactly one ``Project`` per AWS account
/// (environment), enforced by `git_repositories_project_account_idx`. The
/// `onDelete: .restrict` on `project_id` prevents deleting a project while any
/// repository still points at it. Lookup indexes by `repository_name` and
/// `(aws_account_id, aws_region)` support common operational queries.
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
            .create()

        guard let sql = database as? SQLDatabase else { return }
        try await sql.raw(
            "CREATE INDEX git_repositories_name_idx ON git_repositories (repository_name)"
        ).run()
        try await sql.raw(
            "CREATE INDEX git_repositories_aws_lookup_idx ON git_repositories (aws_account_id, aws_region)"
        ).run()
        try await sql.raw(
            """
            CREATE UNIQUE INDEX git_repositories_project_account_idx
            ON git_repositories (project_id, aws_account_id)
            """
        ).run()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(GitRepository.schema).delete()
    }
}
