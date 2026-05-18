import FluentKit
import Foundation
import NavigatorDAL

/// Event kinds the entity activity timeline surfaces.
enum EntityActivityKind: String, Sendable {
    case created
    case updated
    case personAssigned
    case shareClassAdded
    case shareIssuanceMade
    case addressAdded

    var label: String {
        switch self {
        case .created: "Directory entry"
        case .updated: "Entity updated"
        case .personAssigned: "Person joined"
        case .shareClassAdded: "Share class"
        case .shareIssuanceMade: "Issuance"
        case .addressAdded: "Address"
        }
    }

    var chipPalette: String {
        switch self {
        case .created: "bg-green-100 text-green-800"
        case .updated: "bg-blue-100 text-blue-800"
        case .personAssigned: "bg-indigo-100 text-indigo-800"
        case .shareClassAdded: "bg-purple-100 text-purple-800"
        case .shareIssuanceMade: "bg-rose-100 text-rose-800"
        case .addressAdded: "bg-amber-100 text-amber-800"
        }
    }

    func event(at timestamp: Date, description: String, href: String? = nil) -> AdminActivityEvent {
        AdminActivityEvent(
            kind: rawValue,
            label: label,
            chipPalette: chipPalette,
            timestamp: timestamp,
            description: description,
            href: href
        )
    }
}

/// Loads every activity event for an entity, newest-first.
func loadEntityActivity(
    entity: Entity,
    db: Database
) async throws -> [AdminActivityEvent] {
    guard let entityID = entity.id else { return [] }
    var events: [AdminActivityEvent] = []

    if let createdAt = entity.insertedAt {
        events.append(
            EntityActivityKind.created.event(
                at: createdAt,
                description: "\(entity.name) added to the directory."
            )
        )
        if let updatedAt = entity.updatedAt, updatedAt > createdAt {
            events.append(
                EntityActivityKind.updated.event(
                    at: updatedAt,
                    description: "Entity details updated."
                )
            )
        }
    }

    let roles = try await PersonEntityRole.query(on: db)
        .filter(\.$entity.$id == entityID)
        .with(\.$person)
        .all()
    for r in roles {
        if let t = r.insertedAt {
            events.append(
                EntityActivityKind.personAssigned.event(
                    at: t,
                    description: "\(r.person.name) joined as \(r.role.rawValue).",
                    href: "/admin/people/\(r.$person.id.uuidString)"
                )
            )
        }
    }

    let classes = try await ShareClass.query(on: db)
        .filter(\.$entity.$id == entityID)
        .all()
    for sc in classes {
        if let t = sc.insertedAt {
            events.append(
                EntityActivityKind.shareClassAdded.event(
                    at: t,
                    description: "Share class \(sc.name) added (priority \(sc.priority))."
                )
            )
        }
    }

    let issuances = try await ShareIssuance.query(on: db)
        .filter(\.$entity.$id == entityID)
        .all()
    for issuance in issuances {
        if let t = issuance.insertedAt {
            events.append(
                EntityActivityKind.shareIssuanceMade.event(
                    at: t,
                    description: "Shares issued to a \(issuance.shareholderType.rawValue)."
                )
            )
        }
    }

    let addresses = try await Address.query(on: db)
        .filter(\.$entity.$id == entityID)
        .all()
    for a in addresses {
        if let t = a.insertedAt {
            events.append(
                EntityActivityKind.addressAdded.event(
                    at: t,
                    description: "Address added: \(a.street), \(a.city)."
                )
            )
        }
    }

    return events.sorted { $0.timestamp > $1.timestamp }
}
