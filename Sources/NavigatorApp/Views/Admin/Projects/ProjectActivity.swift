import FluentKit
import Foundation
import NavigatorDAL

/// Discrete kinds of events the project activity timeline surfaces.
///
/// Each case carries a stable `rawValue` (test handle), a human-readable
/// `label` (chip text), and a Tailwind color set (chip palette). The
/// loader translates DAL rows into ``AdminActivityEvent`` rows that
/// reference these.
enum ProjectActivityKind: String, Sendable {
    case created
    case updated
    case personAssigned
    case documentAdded
    case repositoryLinked
    case disclosureFiled

    var label: String {
        switch self {
        case .created: "Project created"
        case .updated: "Project updated"
        case .personAssigned: "Person assigned"
        case .documentAdded: "Document added"
        case .repositoryLinked: "Repository linked"
        case .disclosureFiled: "Disclosure filed"
        }
    }

    var chipPalette: String {
        switch self {
        case .created: "bg-green-100 text-green-800"
        case .updated: "bg-blue-100 text-blue-800"
        case .personAssigned: "bg-indigo-100 text-indigo-800"
        case .documentAdded: "bg-amber-100 text-amber-800"
        case .repositoryLinked: "bg-purple-100 text-purple-800"
        case .disclosureFiled: "bg-rose-100 text-rose-800"
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

/// Loads every activity event for a project, newest-first.
///
/// Pure derivation from existing data — see related rows' `insertedAt`
/// values. The "updated" event only fires when the row was actually
/// edited after insert.
func loadProjectActivity(
    project: Project,
    db: Database
) async throws -> [AdminActivityEvent] {
    guard let projectID = project.id else { return [] }
    var events: [AdminActivityEvent] = []

    if let createdAt = project.insertedAt {
        events.append(
            ProjectActivityKind.created.event(
                at: createdAt,
                description: "Project \(project.codename) created."
            )
        )
        if let updatedAt = project.updatedAt, updatedAt > createdAt {
            events.append(
                ProjectActivityKind.updated.event(
                    at: updatedAt,
                    description: "Project details updated."
                )
            )
        }
    }

    let assignments = try await PersonProjectRole.query(on: db)
        .filter(\.$project.$id == projectID)
        .with(\.$person)
        .all()
    for a in assignments {
        if let t = a.insertedAt {
            events.append(
                ProjectActivityKind.personAssigned.event(
                    at: t,
                    description: "\(a.person.name) assigned as \(a.role.rawValue).",
                    href: "/admin/people/\(a.$person.id.uuidString)"
                )
            )
        }
    }

    let documents = try await Document.query(on: db)
        .filter(\.$project.$id == projectID)
        .all()
    for d in documents {
        if let t = d.insertedAt {
            events.append(
                ProjectActivityKind.documentAdded.event(
                    at: t,
                    description: "Document \u{201C}\(d.title)\u{201D} added."
                )
            )
        }
    }

    let repos = try await GitRepository.query(on: db)
        .filter(\.$project.$id == projectID)
        .all()
    for r in repos {
        if let t = r.insertedAt {
            events.append(
                ProjectActivityKind.repositoryLinked.event(
                    at: t,
                    description: "Repository \(r.repositoryName) linked."
                )
            )
        }
    }

    let disclosures = try await Disclosure.query(on: db)
        .filter(\.$project.$id == projectID)
        .with(\.$credential) { $0.with(\.$person) }
        .all()
    for disc in disclosures {
        if let t = disc.insertedAt {
            events.append(
                ProjectActivityKind.disclosureFiled.event(
                    at: t,
                    description: "Disclosure filed for \(disc.credential.person.name).",
                    href: "/admin/disclosures"
                )
            )
        }
    }

    return events.sorted { $0.timestamp > $1.timestamp }
}
