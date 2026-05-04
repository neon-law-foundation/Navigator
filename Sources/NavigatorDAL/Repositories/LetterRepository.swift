import FluentKit

/// Provides database access operations for `Letter` records.
public struct LetterRepository: Sendable {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> Letter? {
        try await Letter.find(id, on: database)
    }

    public func findByMailroom(mailroomId: UUID) async throws -> [Letter] {
        try await Letter.query(on: database)
            .filter(\.$mailroom.$id == mailroomId)
            .all()
    }

    public func findAll() async throws -> [Letter] {
        try await Letter.query(on: database).all()
    }

    public func create(letter: Letter) async throws -> Letter {
        try await letter.save(on: database)
        return letter
    }

    public func update(letter: Letter) async throws -> Letter {
        try await letter.save(on: database)
        return letter
    }

    public func delete(id: UUID) async throws {
        guard let letter = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await letter.delete(on: database)
    }
}
