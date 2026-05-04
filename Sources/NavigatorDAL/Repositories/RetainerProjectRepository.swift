import FluentKit
import Foundation

/// Data access for ``RetainerProject`` pivot records.
public struct RetainerProjectRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> RetainerProject? {
        try await RetainerProject.find(id, on: database)
    }

    public func findByRetainer(retainerId: UUID) async throws -> [RetainerProject] {
        try await RetainerProject.query(on: database)
            .filter(\.$retainer.$id == retainerId)
            .all()
    }

    public func findByProject(projectId: UUID) async throws -> [RetainerProject] {
        try await RetainerProject.query(on: database)
            .filter(\.$project.$id == projectId)
            .all()
    }

    public func create(model: RetainerProject) async throws -> RetainerProject {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let pivot = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await pivot.delete(on: database)
    }
}
