import FluentKit
import Foundation

/// Service for ``Answer`` database operations.
///
/// `AnswerRepository` provides a focused interface for recording and retrieving answers.
/// The primary entry point is ``findOrCreate(questionID:personID:entityID:value:on:)``,
/// which implements an upsert pattern: it returns the existing answer when one already
/// matches the `(question_id, person_id, value)` triple, and creates a new record otherwise.
public struct AnswerRepository: Sendable {

    /// Creates a new `AnswerRepository`.
    ///
    /// - Parameter database: The Fluent database connection to use for all operations.
    public init() {}

    /// Returns the first answer matching `(questionID, personID)`, or `nil` if none exists.
    ///
    /// Use this method when you need to retrieve a previously stored answer for a question
    /// and person combination, regardless of the value.
    ///
    /// - Parameters:
    ///   - questionID: The identifier of the ``Question`` being answered.
    ///   - personID: The identifier of the ``Person`` who provided the answer.
    ///   - entityID: The identifier of the ``Entity`` on whose behalf the answer was given,
    ///     or `nil` if the answer is personal only.
    ///   - database: The Fluent database connection to use.
    /// - Returns: The first matching ``Answer``, or `nil` if none exists.
    /// - Throws: Any database error encountered during the query.
    public func find(
        questionID: UUID,
        personID: UUID,
        entityID: UUID?,
        on database: Database
    ) async throws -> Answer? {
        var query = Answer.query(on: database)
            .filter(\.$question.$id == questionID)
            .filter(\.$person.$id == personID)

        if let entityID = entityID {
            query = query.filter(\.$entity.$id == entityID)
        } else {
            query = query.filter(\.$entity.$id == nil)
        }

        return try await query.first()
    }

    /// Returns the existing answer matching `(questionID, personID, value)`, or creates
    /// and saves a new one if no match is found.
    ///
    /// This method is the idempotent write path for answers. Calling it twice with the
    /// same arguments returns the same persisted record without creating a duplicate.
    ///
    /// - Parameters:
    ///   - questionID: The identifier of the ``Question`` being answered.
    ///   - personID: The identifier of the ``Person`` providing the answer.
    ///   - entityID: The identifier of the ``Entity`` on whose behalf the answer is given,
    ///     or `nil` if the answer is personal only.
    ///   - value: The JSON-serialised answer value.
    ///   - database: The Fluent database connection to use.
    /// - Returns: The existing or newly created ``Answer``.
    /// - Throws: Any database error encountered during the query or save.
    public func findOrCreate(
        questionID: UUID,
        personID: UUID,
        entityID: UUID?,
        value: String,
        on database: Database
    ) async throws -> Answer {
        let jsonValue = Self.normalizeToJSON(value)

        var query = Answer.query(on: database)
            .filter(\.$question.$id == questionID)
            .filter(\.$person.$id == personID)
            .filter(\.$value == jsonValue)

        if let entityID = entityID {
            query = query.filter(\.$entity.$id == entityID)
        } else {
            query = query.filter(\.$entity.$id == nil)
        }

        if let existing = try await query.first() {
            return existing
        }

        let answer = Answer()
        answer.$question.id = questionID
        answer.$person.id = personID
        answer.$entity.id = entityID
        answer.value = jsonValue
        try await answer.save(on: database)
        return answer
    }

    /// Normalises a value to a valid JSON string for storage in the JSONB `value` column.
    ///
    /// If `value` is already valid JSON (an object, array, number, boolean, `null`, or a
    /// properly quoted string) it is returned unchanged. Otherwise it is JSON-encoded as a
    /// string literal — e.g. `Nick Shook` becomes `"Nick Shook"`.
    public static func normalizeToJSON(_ value: String) -> String {
        if let data = value.data(using: .utf8),
            (try? JSONSerialization.jsonObject(with: data)) != nil
        {
            return value
        }
        guard let data = try? JSONEncoder().encode(value),
            let json = String(data: data, encoding: .utf8)
        else {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return json
    }
}
