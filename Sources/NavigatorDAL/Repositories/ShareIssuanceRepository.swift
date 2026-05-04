import FluentKit

/// Provides database access operations for `ShareIssuance` records.
public struct ShareIssuanceRepository: Sendable {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> ShareIssuance? {
        try await ShareIssuance.find(id, on: database)
    }

    public func findByEntity(entityId: UUID) async throws -> [ShareIssuance] {
        try await ShareIssuance.query(on: database)
            .filter(\.$entity.$id == entityId)
            .all()
    }

    public func findAll() async throws -> [ShareIssuance] {
        try await ShareIssuance.query(on: database).all()
    }

    public func create(issuance: ShareIssuance) async throws -> ShareIssuance {
        try await issuance.save(on: database)
        return issuance
    }

    public func update(issuance: ShareIssuance) async throws -> ShareIssuance {
        try await issuance.save(on: database)
        return issuance
    }

    public func delete(id: UUID) async throws {
        guard let issuance = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await issuance.delete(on: database)
    }
}
