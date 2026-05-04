import FluentKit

/// Creates the `projects` table — the top-level container for a matter or engagement.
///
/// `codename` is the stable human-readable handle (unique). `title`, `status`, and
/// `project_type` are nullable because legacy projects pre-dated the addition of
/// those fields; new projects should always populate `status` and `project_type`.
struct CreateProjects: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Project.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("codename", .string, .required)
            .field("title", .string)
            .field("status", .string)
            .field("project_type", .string)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "codename")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Project.schema).delete()
    }
}
