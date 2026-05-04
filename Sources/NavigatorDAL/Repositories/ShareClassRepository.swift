import FluentKit
import Foundation

public struct ShareClassRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> ShareClass? {
        try await ShareClass.find(id, on: database)
    }

    public func findAll() async throws -> [ShareClass] {
        try await ShareClass.query(on: database).all()
    }

    public func findByEntity(entityId: UUID) async throws -> [ShareClass] {
        try await ShareClass.query(on: database)
            .filter(\.$entity.$id == entityId)
            .sort(\.$priority)
            .all()
    }

    public func create(model: ShareClass) async throws -> ShareClass {
        try await model.save(on: database)
        return model
    }

    public func update(model: ShareClass) async throws -> ShareClass {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let shareClass = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await shareClass.delete(on: database)
    }
}
