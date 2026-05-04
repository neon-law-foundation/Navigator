import FluentKit
import Foundation

public struct DisclosureRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> Disclosure? {
        try await Disclosure.find(id, on: database)
    }

    public func findAll() async throws -> [Disclosure] {
        try await Disclosure.query(on: database).all()
    }

    public func findActive() async throws -> [Disclosure] {
        try await Disclosure.query(on: database)
            .filter(\.$active == true)
            .all()
    }

    public func findByProject(projectId: UUID) async throws -> [Disclosure] {
        try await Disclosure.query(on: database)
            .filter(\.$project.$id == projectId)
            .all()
    }

    public func findByCredential(credentialId: UUID) async throws -> [Disclosure] {
        try await Disclosure.query(on: database)
            .filter(\.$credential.$id == credentialId)
            .all()
    }

    public func create(model: Disclosure) async throws -> Disclosure {
        try await model.save(on: database)
        return model
    }

    public func update(model: Disclosure) async throws -> Disclosure {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let disclosure = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await disclosure.delete(on: database)
    }
}
