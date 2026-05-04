import FluentKit
import Foundation
import SQLKit

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
    /// On Postgres this uses a `@>` JSON containment query against the GIN-indexed column.
    /// On SQLite all active retainers are loaded and filtered in Swift.
    public func findByPersonId(_ personId: UUID) async throws -> [Retainer] {
        if let sql = database as? SQLDatabase, sql.dialect.name == "postgresql" {
            let encoded = try encodeClientFilter(type: "person", id: personId)
            struct Row: Decodable { let id: UUID }
            let rows = try await sql.raw(
                "SELECT id FROM retainers WHERE clients @> \(bind: encoded)::jsonb"
            ).all(decoding: Row.self)
            let ids = rows.map(\.id)
            guard !ids.isEmpty else { return [] }
            return try await Retainer.query(on: database).filter(\.$id ~~ ids).all()
        }
        let all = try await findAll()
        return all.filter { retainer in
            retainer.clients.contains { $0.type == .person && $0.id == personId }
        }
    }

    /// Returns all retainers whose `clients` array contains `{type: "entity", id: entityId}`.
    ///
    /// On Postgres this uses a `@>` JSON containment query against the GIN-indexed column.
    /// On SQLite all retainers are loaded and filtered in Swift.
    public func findByEntityId(_ entityId: UUID) async throws -> [Retainer] {
        if let sql = database as? SQLDatabase, sql.dialect.name == "postgresql" {
            let encoded = try encodeClientFilter(type: "entity", id: entityId)
            struct Row: Decodable { let id: UUID }
            let rows = try await sql.raw(
                "SELECT id FROM retainers WHERE clients @> \(bind: encoded)::jsonb"
            ).all(decoding: Row.self)
            let ids = rows.map(\.id)
            guard !ids.isEmpty else { return [] }
            return try await Retainer.query(on: database).filter(\.$id ~~ ids).all()
        }
        let all = try await findAll()
        return all.filter { retainer in
            retainer.clients.contains { $0.type == .entity && $0.id == entityId }
        }
    }

    /// Returns project IDs visible to the client identified by `personId` and/or `entityIds`.
    ///
    /// A retainer grants access when:
    /// - `status == .active`
    /// - `starts_at <= now`
    /// - `ends_at == nil` OR `ends_at > now`
    /// - `clients` contains the person or at least one of the entity IDs
    ///
    /// On Postgres uses `@>` JSON containment on the GIN-indexed `clients` column.
    /// On SQLite loads all active retainers and filters in Swift.
    public func findActiveProjectIds(
        forPersonId personId: UUID,
        entityIds: [UUID]
    ) async throws -> [UUID] {
        let now = Date()
        let activeRetainerIds: [UUID]

        if let sql = database as? SQLDatabase, sql.dialect.name == "postgresql" {
            activeRetainerIds = try await postgresActiveRetainerIds(
                personId: personId,
                entityIds: entityIds,
                now: now,
                sql: sql
            )
        } else {
            activeRetainerIds = try await sqliteActiveRetainerIds(
                personId: personId,
                entityIds: entityIds,
                now: now
            )
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

    // MARK: - Private helpers

    private func encodeClientFilter(type: String, id: UUID) throws -> String {
        // RetainerClient encodes UUIDs as their default string form via JSONEncoder;
        // the `clients` JSONB column is written the same way, so containment (`@>`)
        // matches when we serialise the lookup the same way here.
        let filter = [RetainerClient(type: RetainerClient.ClientType(rawValue: type) ?? .person, id: id)]
        let data = try JSONEncoder().encode(filter)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func postgresActiveRetainerIds(
        personId: UUID,
        entityIds: [UUID],
        now: Date,
        sql: SQLDatabase
    ) async throws -> [UUID] {
        struct Row: Decodable { let id: UUID }

        let personFilter = try encodeClientFilter(type: "person", id: personId)

        var ids: Set<UUID> = []

        // Person match
        let personRows = try await sql.raw(
            """
            SELECT id FROM retainers
            WHERE status = 'active'
            AND starts_at <= \(bind: now)
            AND (ends_at IS NULL OR ends_at > \(bind: now))
            AND clients @> \(bind: personFilter)::jsonb
            """
        ).all(decoding: Row.self)
        ids.formUnion(personRows.map(\.id))

        // Entity matches
        for entityId in entityIds {
            let entityFilter = try encodeClientFilter(type: "entity", id: entityId)
            let entityRows = try await sql.raw(
                """
                SELECT id FROM retainers
                WHERE status = 'active'
                AND starts_at <= \(bind: now)
                AND (ends_at IS NULL OR ends_at > \(bind: now))
                AND clients @> \(bind: entityFilter)::jsonb
                """
            ).all(decoding: Row.self)
            ids.formUnion(entityRows.map(\.id))
        }

        return Array(ids)
    }

    private func sqliteActiveRetainerIds(
        personId: UUID,
        entityIds: [UUID],
        now: Date
    ) async throws -> [UUID] {
        let active = try await Retainer.query(on: database)
            .filter(\.$status == .active)
            .all()

        return active.compactMap { retainer -> UUID? in
            guard let startsAt = retainer.startsAt, startsAt <= now else { return nil }
            if let endsAt = retainer.endsAt, endsAt <= now { return nil }

            let matchesPerson = retainer.clients.contains { $0.type == .person && $0.id == personId }
            let matchesEntity = retainer.clients.contains { client in
                client.type == .entity && entityIds.contains(client.id)
            }
            return (matchesPerson || matchesEntity) ? retainer.id : nil
        }
    }
}
