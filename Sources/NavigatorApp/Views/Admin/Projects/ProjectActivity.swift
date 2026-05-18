import FluentKit
import Foundation
import NavigatorDAL

/// One event in a project's audit-shaped activity timeline.
///
/// Derived at read time from the existing related rows
/// (`PersonProjectRole`, `Document`, `GitRepository`, `Disclosure`) — no
/// new audit table is involved. The kind drives the icon and color on
/// the rendered timeline; the description carries the one-line summary;
/// `href` is the optional deep link to the related resource.
struct ProjectActivityEvent: Sendable, Equatable {
    let kind: ProjectActivityKind
    let timestamp: Date
    let description: String
    let href: String?
}

/// Discrete kinds of events the project activity timeline surfaces.
///
/// Kept narrow on purpose — each case has a stable color in the UI and
/// is something an auditor would recognize as a real change to the
/// matter.
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
}

/// Loads every activity event for a project, newest-first.
///
/// `Project.insertedAt` and `Project.updatedAt` provide the "created"
/// and "updated" markers; the related rows' own `insertedAt` timestamps
/// drive the rest. A project that has never been edited after creation
/// emits only one timestamp (no spurious "updated" event when the row
/// has never been touched after insert).
func loadProjectActivity(
    project: Project,
    db: Database
) async throws -> [ProjectActivityEvent] {
    guard let projectID = project.id else { return [] }

    var events: [ProjectActivityEvent] = []

    if let createdAt = project.insertedAt {
        events.append(
            ProjectActivityEvent(
                kind: .created,
                timestamp: createdAt,
                description: "Project \(project.codename) created.",
                href: nil
            )
        )
        // Only emit an updated event when the row actually changed
        // after insert — otherwise the timeline would show two events
        // that happened at exactly the same instant.
        if let updatedAt = project.updatedAt, updatedAt > createdAt {
            events.append(
                ProjectActivityEvent(
                    kind: .updated,
                    timestamp: updatedAt,
                    description: "Project details updated.",
                    href: nil
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
                ProjectActivityEvent(
                    kind: .personAssigned,
                    timestamp: t,
                    description:
                        "\(a.person.name) assigned as \(a.role.rawValue).",
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
                ProjectActivityEvent(
                    kind: .documentAdded,
                    timestamp: t,
                    description: "Document \u{201C}\(d.title)\u{201D} added.",
                    href: nil
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
                ProjectActivityEvent(
                    kind: .repositoryLinked,
                    timestamp: t,
                    description: "Repository \(r.repositoryName) linked.",
                    href: nil
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
                ProjectActivityEvent(
                    kind: .disclosureFiled,
                    timestamp: t,
                    description:
                        "Disclosure filed for \(disc.credential.person.name).",
                    href: "/admin/disclosures"
                )
            )
        }
    }

    return events.sorted { $0.timestamp > $1.timestamp }
}
