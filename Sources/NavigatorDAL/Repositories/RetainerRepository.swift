import FluentKit
import Foundation

/// Data access for ``Retainer`` records.
public struct RetainerRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    // MARK: - Core CRUD

    public func find(id: UUID) async throws -> Retainer? {
        try await Retainer.find(id, on: database)
    }

    public func findAll() async throws -> [Retainer] {
        try await Retainer.query(on: database).all()
    }

    public func create(model: Retainer) async throws -> Retainer {
        try await model.save(on: database)
        return model
    }

    public func update(model: Retainer) async throws -> Retainer {
        try await model.save(on: database)
        return model
    }

    public func delete(id: UUID) async throws {
        guard let retainer = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        try await retainer.delete(on: database)
    }

    // MARK: - RBAC queries

    /// Returns all retainers with `status == .active`.
    public func findActive() async throws -> [Retainer] {
        try await Retainer.query(on: database)
            .filter(\.$status == .active)
            .all()
    }

    /// Returns all retainers whose `clients` array contains `{type: "person", id: personId}`.
    ///
    /// Membership is checked in Swift on the decoded `clients` array. There is no
    /// portable JSON-containment operator across Postgres and SQLite via Fluent,
    /// and the per-respondent membership set is small enough that scanning all
    /// retainers is acceptable.
    public func findByPersonId(_ personId: UUID) async throws -> [Retainer] {
        let all = try await findAll()
        return all.filter { retainer in
            retainer.clients.value.contains { $0.type == .person && $0.id == personId }
        }
    }

    /// Returns all retainers whose `clients` array contains `{type: "entity", id: entityId}`.
    ///
    /// See ``findByPersonId(_:)`` for the rationale on filtering in Swift rather than SQL.
    public func findByEntityId(_ entityId: UUID) async throws -> [Retainer] {
        let all = try await findAll()
        return all.filter { retainer in
            retainer.clients.value.contains { $0.type == .entity && $0.id == entityId }
        }
    }

    /// Returns project IDs visible to the client identified by `personId` and/or `entityIds`.
    ///
    /// A retainer grants access when:
    /// - `status == .active`
    /// - `starts_at <= now`
    /// - `ends_at == nil` OR `ends_at > now`
    /// - `clients` contains the person or at least one of the entity IDs
    public func findActiveProjectIds(
        forPersonId personId: UUID,
        entityIds: [UUID]
    ) async throws -> [UUID] {
        let now = Date()
        let active = try await Retainer.query(on: database)
            .filter(\.$status == .active)
            .all()

        let activeRetainerIds = active.compactMap { retainer -> UUID? in
            guard let startsAt = retainer.startsAt, startsAt <= now else { return nil }
            if let endsAt = retainer.endsAt, endsAt <= now { return nil }

            let matchesPerson = retainer.clients.value.contains { $0.type == .person && $0.id == personId }
            let matchesEntity = retainer.clients.value.contains { client in
                client.type == .entity && entityIds.contains(client.id)
            }
            return (matchesPerson || matchesEntity) ? retainer.id : nil
        }

        guard !activeRetainerIds.isEmpty else { return [] }

        let pivots = try await RetainerProject.query(on: database)
            .filter(\.$retainer.$id ~~ activeRetainerIds)
            .all()
        return pivots.map { $0.$project.id }
    }

    // MARK: - Lifecycle

    /// Advances a retainer from `pendingSignature` to `active`.
    public func activate(id: UUID, startsAt: Date) async throws -> Retainer {
        guard let retainer = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        retainer.status = .active
        retainer.startsAt = startsAt
        try await retainer.save(on: database)
        return retainer
    }

    /// Closes a retainer, setting `ends_at` and status to `closed`.
    public func close(id: UUID, endsAt: Date) async throws -> Retainer {
        guard let retainer = try await find(id: id) else {
            throw RepositoryError.notFound
        }
        retainer.status = .closed
        retainer.endsAt = endsAt
        try await retainer.save(on: database)
        return retainer
    }

    /// Activates all `pendingSignature` retainers linked to `notationId`.
    ///
    /// Called after a notation step that reaches terminal state `"END"`.
    /// Sets `status = .active` and `starts_at = now` on each matching retainer.
    /// Already-active retainers are left unchanged.
    public func activateRetainersForNotation(notationId: UUID) async throws {
        let retainers = try await Retainer.query(on: database)
            .filter(\.$notation.$id == notationId)
            .filter(\.$status == .pendingSignature)
            .all()
        let now = Date()
        for retainer in retainers {
            retainer.status = .active
            retainer.startsAt = now
            try await retainer.save(on: database)
        }
    }
}
