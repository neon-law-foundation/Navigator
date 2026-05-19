import FluentKit
import Foundation
import NavigatorDAL

/// Builds the cross-resource activity feed rendered below the tile grid
/// on `/admin`.
///
/// Fans out one Fluent query per source (projects, people, entities,
/// notations, inbound email), maps the rows to ``AdminActivityEvent``,
/// merges newest-first, and trims to `limit`. The `since` cutoff drops
/// older rows so the feed can answer "what changed today" without
/// scrolling.
///
/// The kind discriminators here are namespaced (`project.created`,
/// `person.created`, …) so test assertions can distinguish dashboard
/// rows from per-resource rows even though both render through the same
/// ``AdminActivitySection`` chrome.
func loadDashboardActivity(
    db: Database,
    limit: Int = 25,
    since: Date? = nil
) async throws -> [AdminActivityEvent] {
    async let projectEvents = projectsFeed(db: db, since: since)
    async let personEvents = peopleFeed(db: db, since: since)
    async let entityEvents = entitiesFeed(db: db, since: since)
    async let notationEvents = notationsFeed(db: db, since: since)
    async let inboundEvents = inboxFeed(db: db, since: since)

    let merged =
        try await projectEvents
        + personEvents
        + entityEvents
        + notationEvents
        + inboundEvents
    return Array(merged.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
}

private func projectsFeed(db: Database, since: Date?) async throws -> [AdminActivityEvent] {
    var q = Project.query(on: db)
    if let since {
        q = q.group(.or) { group in
            group.filter(\.$insertedAt >= since)
                .filter(\.$updatedAt >= since)
        }
    }
    let projects = try await q.all()
    var out: [AdminActivityEvent] = []
    for p in projects {
        if let created = p.insertedAt, since == nil || created >= since! {
            out.append(
                AdminActivityEvent(
                    kind: "project.created",
                    label: "Project created",
                    chipPalette: "bg-green-100 text-green-800",
                    timestamp: created,
                    description: "Project \(p.codename) created.",
                    href: "/admin/projects/\(p.id?.uuidString ?? "")"
                )
            )
        }
        if let updated = p.updatedAt, let created = p.insertedAt, updated > created,
            since == nil || updated >= since!
        {
            out.append(
                AdminActivityEvent(
                    kind: "project.updated",
                    label: "Project updated",
                    chipPalette: "bg-blue-100 text-blue-800",
                    timestamp: updated,
                    description: "Project \(p.codename) updated.",
                    href: "/admin/projects/\(p.id?.uuidString ?? "")"
                )
            )
        }
    }
    return out
}

private func peopleFeed(db: Database, since: Date?) async throws -> [AdminActivityEvent] {
    var q = Person.query(on: db)
    if let since { q = q.filter(\.$insertedAt >= since) }
    let people = try await q.all()
    return people.compactMap { person in
        guard let created = person.insertedAt else { return nil }
        return AdminActivityEvent(
            kind: "person.created",
            label: "Person added",
            chipPalette: "bg-indigo-100 text-indigo-800",
            timestamp: created,
            description: "\(person.name) added.",
            href: "/admin/people/\(person.id?.uuidString ?? "")"
        )
    }
}

private func entitiesFeed(db: Database, since: Date?) async throws -> [AdminActivityEvent] {
    var q = Entity.query(on: db)
    if let since { q = q.filter(\.$insertedAt >= since) }
    let entities = try await q.all()
    return entities.compactMap { entity in
        guard let created = entity.insertedAt else { return nil }
        return AdminActivityEvent(
            kind: "entity.created",
            label: "Entity added",
            chipPalette: "bg-purple-100 text-purple-800",
            timestamp: created,
            description: "Entity \(entity.name) added.",
            href: "/admin/entities/\(entity.id?.uuidString ?? "")"
        )
    }
}

private func notationsFeed(db: Database, since: Date?) async throws -> [AdminActivityEvent] {
    var q = Notation.query(on: db)
    if let since { q = q.filter(\.$insertedAt >= since) }
    let notations = try await q.with(\.$template).all()
    return notations.compactMap { n in
        guard let created = n.insertedAt else { return nil }
        return AdminActivityEvent(
            kind: "notation.created",
            label: "Notation created",
            chipPalette: "bg-amber-100 text-amber-800",
            timestamp: created,
            description: "Notation from \(n.template.code ?? "\u{2014}").",
            href: "/admin/notations/\(n.id?.uuidString ?? "")"
        )
    }
}

private func inboxFeed(db: Database, since: Date?) async throws -> [AdminActivityEvent] {
    var q = EmailMessage.query(on: db)
    if let since { q = q.filter(\.$receivedAt >= since) }
    let messages = try await q.all()
    return messages.compactMap { m in
        guard m.direction == .inbound else { return nil }
        return AdminActivityEvent(
            kind: "inbox.received",
            label: "Mail received",
            chipPalette: "bg-rose-100 text-rose-800",
            timestamp: m.receivedAt,
            description: "\(m.fromName ?? m.fromAddress): \(m.subject)",
            href: "/admin/inbox/\(m.id?.uuidString ?? "")"
        )
    }
}
