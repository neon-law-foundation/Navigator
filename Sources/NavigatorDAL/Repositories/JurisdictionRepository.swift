import FluentKit
import Foundation

public struct JurisdictionRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> Jurisdiction? {
        try await Jurisdiction.find(id, on: database)
    }

    public func findByCode(_ code: String) async throws -> Jurisdiction? {
        try await Jurisdiction.query(on: database)
            .filter(\.$code == code)
            .first()
    }

    public func findAll() async throws -> [Jurisdiction] {
        try await Jurisdiction.query(on: database).all()
    }

    public func create(model: Jurisdiction) async throws -> Jurisdiction {
        try await model.save(on: database)
        return model
    }

    public func update(model: Jurisdiction) async throws -> Jurisdiction {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let jurisdiction = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await jurisdiction.delete(on: database)
    }
}
