import FluentKit
import Foundation

protocol RepositoryProtocol {
    func find(id: UUID) async throws -> (any Model)?
    func findAll() async throws -> [any Model]
    func create(model: any Model) async throws -> any Model
    func update(model: any Model) async throws -> any Model
    func delete(id: UUID) async throws
}

public enum RepositoryError: Error {
    case notFound
    case alreadyExists
    case invalidModel
    case databaseError(Error)
}
