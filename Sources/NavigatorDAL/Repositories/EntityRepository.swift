import FluentKit
import Foundation

public struct EntityRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> Entity? {
        try await Entity.find(id, on: database)
    }

    public func findAll() async throws -> [Entity] {
        try await Entity.query(on: database).all()
    }

    public func findByType(legalEntityTypeId: UUID) async throws -> [Entity] {
        try await Entity.query(on: database)
            .filter(\.$legalEntityType.$id == legalEntityTypeId)
            .all()
    }

    public func create(model: Entity) async throws -> Entity {
        try await model.save(on: database)
        return model
    }

    public func update(model: Entity) async throws -> Entity {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let entity = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await entity.delete(on: database)
    }
}
