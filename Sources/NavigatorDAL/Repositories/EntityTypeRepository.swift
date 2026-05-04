import FluentKit
import Foundation

public struct EntityTypeRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> EntityType? {
        try await EntityType.find(id, on: database)
    }

    public func findAll() async throws -> [EntityType] {
        try await EntityType.query(on: database).all()
    }

    public func findByJurisdiction(jurisdictionId: UUID) async throws -> [EntityType] {
        try await EntityType.query(on: database)
            .filter(\.$jurisdiction.$id == jurisdictionId)
            .all()
    }

    public func create(model: EntityType) async throws -> EntityType {
        try await model.save(on: database)
        return model
    }

    public func update(model: EntityType) async throws -> EntityType {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let entityType = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await entityType.delete(on: database)
    }
}
