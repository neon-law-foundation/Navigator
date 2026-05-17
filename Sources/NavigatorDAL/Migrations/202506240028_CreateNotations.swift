import FluentKit

/// Creates the `notations` table — formal records placed on a respondent's file
/// linking a ``Template`` to a ``Person`` and/or ``Entity`` and tracking the
/// assignment through its lifecycle via an append-only `state_history`.
///
/// `state_history` is a JSONB document persisted via ``JSONStored``; the
/// current state is `stateHistory.value.last?.toState` and a notation is closed
/// when that equals `"END"`. `answers` is a JSONB map of question code →
/// answer row UUID, frozen at creation time. `rendered_content` is the
/// template markdown with answers interpolated, captured at the same moment.
///
/// Active-assignment uniqueness (one open notation per template+respondent
/// pair) is enforced by `NotationService.hasActiveAssignment(...)`. A
/// portable Fluent migration cannot express the partial unique index the
/// Postgres deployment used to carry, so the rule is checked at the service
/// layer on both engines.
struct CreateNotations: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Notation.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("template_id", .uuid, .required, .references("templates", "id"))
            .field("person_id", .uuid, .references("people", "id"))
            .field("entity_id", .uuid, .references("entities", "id"))
            .field("state_history", .json, .required)
            .field("answers", .json, .required)
            .field("rendered_content", .string)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Notation.schema).delete()
    }
}
