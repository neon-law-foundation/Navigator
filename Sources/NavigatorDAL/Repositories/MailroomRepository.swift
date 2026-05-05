import FluentKit
import Foundation

/// Provides database access operations for `Mailroom` records.
public struct MailroomRepository: Sendable {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> Mailroom? {
        try await Mailroom.find(id, on: database)
    }

    public func findByName(_ name: String) async throws -> Mailroom? {
        try await Mailroom.query(on: database)
            .filter(\.$name == name)
            .first()
    }

    public func findAll() async throws -> [Mailroom] {
        try await Mailroom.query(on: database).all()
    }

    public func create(mailroom: Mailroom) async throws -> Mailroom {
        try await mailroom.save(on: database)
        return mailroom
    }

    public func update(mailroom: Mailroom) async throws -> Mailroom {
        try await mailroom.save(on: database)
        return mailroom
    }

    public func delete(id: UUID) async throws {
        guard let mailroom = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await mailroom.delete(on: database)
    }
}
