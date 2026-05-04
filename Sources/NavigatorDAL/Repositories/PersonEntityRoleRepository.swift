import FluentKit
import Foundation

public struct PersonEntityRoleRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> PersonEntityRole? {
        try await PersonEntityRole.find(id, on: database)
    }

    public func findAll() async throws -> [PersonEntityRole] {
        try await PersonEntityRole.query(on: database).all()
    }

    public func findByPerson(personId: UUID) async throws -> [PersonEntityRole] {
        try await PersonEntityRole.query(on: database)
            .filter(\.$person.$id == personId)
            .all()
    }

    public func findByEntity(entityId: UUID) async throws -> [PersonEntityRole] {
        try await PersonEntityRole.query(on: database)
            .filter(\.$entity.$id == entityId)
            .all()
    }

    public func findByRole(_ role: PersonEntityRoleType) async throws -> [PersonEntityRole] {
        try await PersonEntityRole.query(on: database)
            .filter(\.$role == role)
            .all()
    }

    public func create(model: PersonEntityRole) async throws -> PersonEntityRole {
        try await model.save(on: database)
        return model
    }

    public func update(model: PersonEntityRole) async throws -> PersonEntityRole {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let role = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await role.delete(on: database)
    }
}
