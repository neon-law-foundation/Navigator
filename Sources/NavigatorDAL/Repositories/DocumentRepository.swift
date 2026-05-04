import FluentKit

/// Provides database access operations for `Document` records.
public struct DocumentRepository: Sendable {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: UUID) async throws -> Document? {
        try await Document.find(id, on: database)
    }

    public func findByProject(projectId: UUID) async throws -> [Document] {
        try await Document.query(on: database)
            .filter(\.$project.$id == projectId)
            .all()
    }

    public func findAll() async throws -> [Document] {
        try await Document.query(on: database).all()
    }

    public func create(document: Document) async throws -> Document {
        try await document.save(on: database)
        return document
    }

    public func update(document: Document) async throws -> Document {
        try await document.save(on: database)
        return document
    }

    public func delete(id: UUID) async throws {
        guard let document = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await document.delete(on: database)
    }
}
