import FluentKit
import Foundation

public struct CredentialRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> Credential? {
        try await Credential.find(id, on: database)
    }

    public func findAll() async throws -> [Credential] {
        try await Credential.query(on: database).all()
    }

    public func findByPerson(personId: UUID) async throws -> [Credential] {
        try await Credential.query(on: database)
            .filter(\.$person.$id == personId)
            .all()
    }

    public func findByJurisdiction(jurisdictionId: UUID) async throws -> [Credential] {
        try await Credential.query(on: database)
            .filter(\.$jurisdiction.$id == jurisdictionId)
            .all()
    }

    public func create(model: Credential) async throws -> Credential {
        try await model.save(on: database)
        return model
    }

    public func update(model: Credential) async throws -> Credential {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let credential = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await credential.delete(on: database)
    }
}
