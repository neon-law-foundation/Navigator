import FluentKit
import Foundation

/// Provides read and append access to the ``UserRoleAudit`` table.
///
/// Audit rows are append-only — this repository exposes `create` but
/// intentionally omits update and delete operations.
public struct UserRoleAuditRepository: Sendable {

    private let database: Database

    /// Creates a new `UserRoleAuditRepository`.
    ///
    /// - Parameter database: The Fluent database connection to use for all operations.
    public init(database: Database) {
        self.database = database
    }

    /// Returns audit rows for a given user, newest first.
    ///
    /// - Parameters:
    ///   - userId: The identifier of the user whose role history to retrieve.
    ///   - limit: Maximum number of rows to return. Defaults to 50.
    /// - Returns: An array of ``UserRoleAudit`` rows ordered by `inserted_at` descending.
    public func findByUser(userId: UUID, limit: Int = 50) async throws -> [UserRoleAudit] {
        try await UserRoleAudit.query(on: database)
            .filter(\.$user.$id == userId)
            .sort(\.$insertedAt, .descending)
            .limit(limit)
            .all()
    }

    /// Persists a new audit row.
    ///
    /// - Parameter model: The ``UserRoleAudit`` instance to save.
    /// - Returns: The saved instance with its database-generated `id` populated.
    public func create(model: UserRoleAudit) async throws -> UserRoleAudit {
        try await model.save(on: database)
        return model
    }
}
