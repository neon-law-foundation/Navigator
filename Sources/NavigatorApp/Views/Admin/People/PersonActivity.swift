import FluentKit
import Foundation
import NavigatorDAL

/// Event kinds the person activity timeline surfaces.
///
/// Mirrors ``ProjectActivityKind`` in shape: each case carries a raw
/// `rawValue` (the `data-kind` attribute on the rendered chip), a chip
/// `label`, and a Tailwind chip `chipPalette`.
enum PersonActivityKind: String, Sendable {
    case created
    case updated
    case projectAssigned
    case entityRoleAssigned
    case credentialIssued

    var label: String {
        switch self {
        case .created: "Directory entry"
        case .updated: "Profile updated"
        case .projectAssigned: "Project assignment"
        case .entityRoleAssigned: "Entity role"
        case .credentialIssued: "Credential issued"
        }
    }

    var chipPalette: String {
        switch self {
        case .created: "bg-green-100 text-green-800"
        case .updated: "bg-blue-100 text-blue-800"
        case .projectAssigned: "bg-indigo-100 text-indigo-800"
        case .entityRoleAssigned: "bg-purple-100 text-purple-800"
        case .credentialIssued: "bg-rose-100 text-rose-800"
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

/// Loads every activity event for a person, newest-first.
///
/// Derived from the related rows' `insertedAt` columns —
/// `PersonProjectRole`, `PersonEntityRole`, `Credential`. The "updated"
/// event only fires when the person row was actually edited after
/// insert.
func loadPersonActivity(
    person: Person,
    db: Database
) async throws -> [AdminActivityEvent] {
    guard let personID = person.id else { return [] }
    var events: [AdminActivityEvent] = []

    if let createdAt = person.insertedAt {
        events.append(
            PersonActivityKind.created.event(
                at: createdAt,
                description: "\(person.name) added to the directory."
            )
        )
        if let updatedAt = person.updatedAt, updatedAt > createdAt {
            events.append(
                PersonActivityKind.updated.event(
                    at: updatedAt,
                    description: "Profile updated."
                )
            )
        }
    }

    let projectRoles = try await PersonProjectRole.query(on: db)
        .filter(\.$person.$id == personID)
        .with(\.$project)
        .all()
    for r in projectRoles {
        if let t = r.insertedAt {
            events.append(
                PersonActivityKind.projectAssigned.event(
                    at: t,
                    description: "Assigned to \(r.project.codename) as \(r.role.rawValue).",
                    href: "/admin/projects/\(r.$project.id.uuidString)"
                )
            )
        }
    }

    let entityRoles = try await PersonEntityRole.query(on: db)
        .filter(\.$person.$id == personID)
        .with(\.$entity)
        .all()
    for r in entityRoles {
        if let t = r.insertedAt {
            events.append(
                PersonActivityKind.entityRoleAssigned.event(
                    at: t,
                    description: "Took the \(r.role.rawValue) role on \(r.entity.name).",
                    href: "/admin/entities/\(r.$entity.id.uuidString)"
                )
            )
        }
    }

    let credentials = try await Credential.query(on: db)
        .filter(\.$person.$id == personID)
        .with(\.$jurisdiction)
        .all()
    for c in credentials {
        if let t = c.insertedAt {
            events.append(
                PersonActivityKind.credentialIssued.event(
                    at: t,
                    description: "License \(c.licenseNumber) issued in \(c.jurisdiction.name).",
                    href: "/admin/credentials"
                )
            )
        }
    }

    return events.sorted { $0.timestamp > $1.timestamp }
}
