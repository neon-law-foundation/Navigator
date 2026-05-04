import FluentKit
import Foundation

/// Repository for managing person-to-project role memberships.
public struct PersonProjectRoleRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func findByPerson(personId: UUID) async throws -> [PersonProjectRole] {
        try await PersonProjectRole.query(on: database)
            .filter(\.$person.$id == personId)
            .all()
    }

    public func findByProject(projectId: UUID) async throws -> [PersonProjectRole] {
        try await PersonProjectRole.query(on: database)
            .filter(\.$project.$id == projectId)
            .all()
    }

    /// Returns project IDs the person is a member of (staff or client).
    public func findProjectIds(forPersonId personId: UUID) async throws -> [UUID] {
        let roles = try await PersonProjectRole.query(on: database)
            .filter(\.$person.$id == personId)
            .all()
        return roles.compactMap { $0.$project.id }
    }

    public func create(model: PersonProjectRole) async throws -> PersonProjectRole {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let role = try await PersonProjectRole.find(id, on: database) else {
            throw RepositoryError.notFound
        }
        try await role.delete(on: database)
    }
}
