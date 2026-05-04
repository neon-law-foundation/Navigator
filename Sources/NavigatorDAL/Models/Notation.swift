import FluentKit
import Foundation
import SQLKit

/// A formal record that a ``Template`` has been assigned to a specific respondent.
///
/// A `Notation` links a ``Template`` to a person, entity, or both, and tracks the
/// assignment through its lifecycle using an append-only state history. The term
/// "notation" reflects the legal concept of a formal record placed on a party's file.
///
/// The assignment enforces business rules based on the template's respondent type:
/// - For `.person` templates, only `person_id` must be set
/// - For `.entity` templates, only `entity_id` must be set
/// - For `.personAndEntity` templates, both IDs must be set
///
/// The current state is always `stateHistory.last?.toState`. A notation is closed
/// when `toState == "END"`. Service-layer checks prevent duplicate active notations
/// for the same template and respondent combination.
///
/// ## Topics
///
/// ### Creating and Validating Notations
///
/// - ``init()``
/// - ``validate(on:)``
///
/// ### Checking Notation Status
///
/// - ``hasActiveAssignment(templateID:personID:entityID:on:)``
///
/// ### Properties
///
/// - ``id``
/// - ``template``
/// - ``person``
/// - ``entity``
/// - ``stateHistory``
/// - ``answers``
/// - ``renderedContent``
/// - ``insertedAt``
/// - ``updatedAt``
public final class Notation: Model, @unchecked Sendable {
    public static let schema = "notations"

    /// The unique identifier for this notation.
    @ID(key: .id)
    public var id: UUID?

    /// The template this notation is based on.
    @Parent(key: "template_id")
    public var template: Template

    /// The person assigned to this notation, if applicable.
    ///
    /// Required when the template's respondent type is `.person` or `.personAndEntity`.
    /// Must be `nil` when the respondent type is `.entity`.
    @OptionalParent(key: "person_id")
    public var person: Person?

    /// The entity assigned to this notation, if applicable.
    ///
    /// Required when the template's respondent type is `.entity` or `.personAndEntity`.
    /// Must be `nil` when the respondent type is `.person`.
    @OptionalParent(key: "entity_id")
    public var entity: Entity?

    /// The append-only history of workflow transitions for this notation.
    ///
    /// Current state is `stateHistory.last?.toState`. A notation is closed when
    /// `stateHistory.last?.toState == "END"`. An empty history means no transitions
    /// have been recorded yet.
    @Field(key: "state_history")
    public var stateHistory: [NotationEvent]

    /// Questionnaire answers collected at notation creation time, keyed by question code.
    ///
    /// Maps question code to Answer row UUID. Question codes are unique across the questions table.
    @Field(key: "answers")
    public var answers: [String: UUID]

    /// The template markdown with questionnaire answers interpolated.
    ///
    /// Captured at notation creation time. `nil` when the template has no questionnaire.
    @OptionalField(key: "rendered_content")
    public var renderedContent: String?

    /// The timestamp when this notation was created.
    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    /// The timestamp when this notation was last updated.
    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    /// Creates a new notation instance.
    public init() {
        self.stateHistory = []
        self.answers = [:]
    }

    /// Validates that the notation has the correct person and entity IDs based on the template's respondent type.
    ///
    /// Enforces business rules by checking that the notation's person and entity IDs
    /// match the requirements of the template's respondent type:
    /// - `.person` requires `person_id` set and `entity_id` nil
    /// - `.entity` requires `entity_id` set and `person_id` nil
    /// - `.personAndEntity` requires both IDs set
    ///
    /// Call this method before saving a new notation to ensure data integrity.
    ///
    /// - Parameter database: The database connection to use for loading the template.
    /// - Throws: `NotationError.invalidAssignment` if the IDs don't match the respondent type requirements.
    public func validate(on database: Database) async throws {
        try await self.$template.load(on: database)

        let personID = self.$person.id
        let entityID = self.$entity.id

        switch self.template.respondentType {
        case .person:
            guard personID != nil && entityID == nil else {
                throw NotationError.invalidAssignment(
                    "For respondent type 'person', person_id must be set and entity_id must be nil"
                )
            }
        case .entity:
            guard entityID != nil && personID == nil else {
                throw NotationError.invalidAssignment(
                    "For respondent type 'entity', entity_id must be set and person_id must be nil"
                )
            }
        case .personAndEntity:
            guard personID != nil && entityID != nil else {
                throw NotationError.invalidAssignment(
                    "For respondent type 'person_and_entity', both person_id and entity_id must be set"
                )
            }
        }
    }

    /// Checks if an active notation already exists for the same template and respondent combination.
    ///
    /// A notation is considered active if its `stateHistory` last event's `toState` is not `"END"`.
    /// Use this method before creating a new notation to provide better error messages than relying
    /// on database constraint violations.
    ///
    /// - Parameters:
    ///   - templateID: The ID of the template to check.
    ///   - personID: The person ID to check, or `nil` if not applicable.
    ///   - entityID: The entity ID to check, or `nil` if not applicable.
    ///   - database: The database connection to use for the query.
    /// - Returns: `true` if an active notation exists, `false` otherwise.
    /// - Throws: Database errors that occur during the query.
    public static func hasActiveAssignment(
        templateID: UUID,
        personID: UUID?,
        entityID: UUID?,
        on database: Database
    ) async throws -> Bool {
        var query = Notation.query(on: database)
            .filter(\.$template.$id == templateID)

        if let personID = personID {
            query = query.filter(\.$person.$id == personID)
        } else {
            query = query.filter(\.$person.$id == nil)
        }

        if let entityID = entityID {
            query = query.filter(\.$entity.$id == entityID)
        } else {
            query = query.filter(\.$entity.$id == nil)
        }

        guard let sql = database as? SQLDatabase else {
            let notations = try await query.all()
            return notations.contains { $0.stateHistory.last?.toState != "END" }
        }

        let isPostgres = sql.dialect.name == "postgresql"
        let activeFilter =
            isPostgres
            ? "state_history->-1->>'toState' != 'END'"
            : "json_extract(state_history, '$[#-1].toState') != 'END'"

        struct FoundRow: Decodable { let found: Int }

        if let pid = personID, let eid = entityID {
            return try await sql.raw(
                """
                SELECT 1 AS found FROM notations
                WHERE template_id = \(bind: templateID)
                AND person_id = \(bind: pid)
                AND entity_id = \(bind: eid)
                AND \(unsafeRaw: activeFilter)
                LIMIT 1
                """
            ).first(decoding: FoundRow.self) != nil
        } else if let pid = personID {
            return try await sql.raw(
                """
                SELECT 1 AS found FROM notations
                WHERE template_id = \(bind: templateID)
                AND person_id = \(bind: pid)
                AND entity_id IS NULL
                AND \(unsafeRaw: activeFilter)
                LIMIT 1
                """
            ).first(decoding: FoundRow.self) != nil
        } else if let eid = entityID {
            return try await sql.raw(
                """
                SELECT 1 AS found FROM notations
                WHERE template_id = \(bind: templateID)
                AND person_id IS NULL
                AND entity_id = \(bind: eid)
                AND \(unsafeRaw: activeFilter)
                LIMIT 1
                """
            ).first(decoding: FoundRow.self) != nil
        } else {
            return try await sql.raw(
                """
                SELECT 1 AS found FROM notations
                WHERE template_id = \(bind: templateID)
                AND person_id IS NULL
                AND entity_id IS NULL
                AND \(unsafeRaw: activeFilter)
                LIMIT 1
                """
            ).first(decoding: FoundRow.self) != nil
        }
    }
}
