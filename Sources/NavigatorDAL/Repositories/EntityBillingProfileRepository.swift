import FluentKit
import Foundation

/// Persists and retrieves ``EntityBillingProfile`` rows.
///
/// Provides the standard CRUD surface plus two convenience finders used by
/// the Xero sync job:
///
/// - ``findByExternalContact(provider:externalContactId:)`` — resolves a
///   provider-side contact UUID back to a Navigator entity, used when
///   ingesting invoices whose payload carries only the provider contact ID.
/// - ``findForEntity(entityId:provider:)`` — resolves a Navigator entity to
///   its profile for a given provider, used when Navigator-driven work
///   needs to push something into the provider.
public struct EntityBillingProfileRepository: Sendable {

    private let database: Database

    /// Creates a new `EntityBillingProfileRepository`.
    ///
    /// - Parameter database: The Fluent database connection used for all operations.
    public init(database: Database) {
        self.database = database
    }

    /// Returns the billing profile with the given identifier, or `nil` if none exists.
    public func find(id: UUID) async throws -> EntityBillingProfile? {
        try await EntityBillingProfile.find(id, on: database)
    }

    /// Returns every billing profile in the database.
    public func findAll() async throws -> [EntityBillingProfile] {
        try await EntityBillingProfile.query(on: database).all()
    }

    /// Persists a new billing profile row.
    ///
    /// - Parameter model: The profile to save. `entity_id`, `provider`, and
    ///   `external_contact_id` must be populated.
    /// - Returns: The saved profile with its database-generated `id`.
    public func create(model: EntityBillingProfile) async throws -> EntityBillingProfile {
        try await model.save(on: database)
        return model
    }

    /// Persists changes to an existing billing profile row.
    public func update(model: EntityBillingProfile) async throws -> EntityBillingProfile {
        try await model.save(on: database)
        return model
    }

    /// Deletes the billing profile with the given identifier.
    ///
    /// - Throws: ``RepositoryError/notFound`` if no row matches.
    public func delete(id: UUID) async throws {
        guard let profile = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await profile.delete(on: database)
    }

    /// Returns the profile mirroring a specific provider-side contact, or `nil`.
    ///
    /// The `(provider, external_contact_id)` pair is globally unique across
    /// Navigator, so at most one row can match.
    ///
    /// - Parameters:
    ///   - provider: The billing provider to scope the lookup to.
    ///   - externalContactId: The provider-side contact identifier (e.g.
    ///     a Xero `ContactID` UUID string).
    public func findByExternalContact(
        provider: BillingProvider,
        externalContactId: String
    ) async throws -> EntityBillingProfile? {
        try await EntityBillingProfile.query(on: database)
            .filter(\.$provider == provider)
            .filter(\.$externalContactId == externalContactId)
            .first()
    }

    /// Returns the entity's profile for the given provider, or `nil` if none exists.
    ///
    /// The `(entity_id, provider)` pair is unique, so at most one row can match.
    ///
    /// - Parameters:
    ///   - entityId: The Navigator ``Entity`` identifier.
    ///   - provider: The billing provider to scope the lookup to.
    public func findForEntity(
        entityId: UUID,
        provider: BillingProvider
    ) async throws -> EntityBillingProfile? {
        try await EntityBillingProfile.query(on: database)
            .filter(\.$entity.$id == entityId)
            .filter(\.$provider == provider)
            .first()
    }
}
