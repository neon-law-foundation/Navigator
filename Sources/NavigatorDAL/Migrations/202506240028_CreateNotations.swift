import FluentKit
import FluentSQL
import SQLKit

/// Creates the `notations` table — formal records placed on a respondent's file
/// linking a ``Template`` to a ``Person`` and/or ``Entity`` and tracking the
/// assignment through its lifecycle via an append-only `state_history`.
///
/// `state_history` is a JSON array of `NotationEvent` rows; the current state
/// is `state_history[-1].toState` and a notation is closed when that equals
/// `"END"`. `answers` is a JSON map of question code → answer row UUID, frozen
/// at creation time. `rendered_content` is the template markdown with answers
/// interpolated, captured at the same moment.
///
/// The Postgres partial unique index `notations_unique_active_assignment`
/// prevents two simultaneous active notations for the same template+respondent
/// pair. The nil UUID acts as a NULL sentinel so two NULL FKs collide in the
/// uniqueness check (Postgres unique indexes otherwise treat NULL ≠ NULL).
/// SQLite tests rely on service-layer checks instead.
struct CreateNotations: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Notation.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("template_id", .uuid, .required, .references("templates", "id"))
            .field("person_id", .uuid, .references("people", "id"))
            .field("entity_id", .uuid, .references("entities", "id"))
            .field("state_history", .json, .required, .sql(.default("[]")))
            .field("answers", .json, .required, .sql(.default("{}")))
            .field("rendered_content", .string)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()

        guard let sql = database as? SQLDatabase else { return }
        guard sql.dialect.name == "postgresql" else { return }
        try await sql.raw(
            """
            CREATE UNIQUE INDEX notations_unique_active_assignment
            ON notations (
                template_id,
                COALESCE(person_id, '00000000-0000-0000-0000-000000000000'::uuid),
                COALESCE(entity_id, '00000000-0000-0000-0000-000000000000'::uuid)
            )
            WHERE state_history->-1->>'toState' != 'END'
            """
        ).run()
    }

    func revert(on database: any Database) async throws {
        if let sql = database as? SQLDatabase, sql.dialect.name == "postgresql" {
            try await sql.raw(
                "DROP INDEX IF EXISTS notations_unique_active_assignment"
            ).run()
        }
        try await database.schema(Notation.schema).delete()
    }
}
