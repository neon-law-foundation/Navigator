import FluentKit
import Foundation

public struct RelationshipLogRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> RelationshipLog? {
        try await RelationshipLog.find(id, on: database)
    }

    public func findAll() async throws -> [RelationshipLog] {
        try await RelationshipLog.query(on: database).all()
    }

    public func findByProject(projectId: UUID) async throws -> [RelationshipLog] {
        try await RelationshipLog.query(on: database)
            .filter(\.$project.$id == projectId)
            .all()
    }

    public func findByCredential(credentialId: UUID) async throws -> [RelationshipLog] {
        try await RelationshipLog.query(on: database)
            .filter(\.$credential.$id == credentialId)
            .all()
    }

    public func create(model: RelationshipLog) async throws -> RelationshipLog {
        try await model.save(on: database)
        return model
    }

    public func update(model: RelationshipLog) async throws -> RelationshipLog {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let log = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await log.delete(on: database)
    }
}
