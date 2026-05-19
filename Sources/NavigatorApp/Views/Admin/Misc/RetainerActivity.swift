import FluentKit
import Foundation
import NavigatorDAL

/// Event kinds the retainer activity timeline surfaces.
enum RetainerActivityKind: String, Sendable {
    case created
    case accessStarted
    case accessEnded
    case projectAttached

    var label: String {
        switch self {
        case .created: "Retainer drafted"
        case .accessStarted: "Access started"
        case .accessEnded: "Access ended"
        case .projectAttached: "Project attached"
        }
    }

    var chipPalette: String {
        switch self {
        case .created: "bg-green-100 text-green-800"
        case .accessStarted: "bg-blue-100 text-blue-800"
        case .accessEnded: "bg-rose-100 text-rose-800"
        case .projectAttached: "bg-indigo-100 text-indigo-800"
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

/// Builds the activity timeline for a retainer.
///
/// `startsAt` and `endsAt` carry the lifecycle moments. The
/// `RetainerProject` join rows' `insertedAt` is the attachment time.
func loadRetainerActivity(
    retainer: Retainer,
    db: Database
) async throws -> [AdminActivityEvent] {
    guard let retainerID = retainer.id else { return [] }
    var events: [AdminActivityEvent] = []

    if let createdAt = retainer.insertedAt {
        events.append(
            RetainerActivityKind.created.event(
                at: createdAt,
                description: "Retainer drafted with status \(retainer.status.rawValue)."
            )
        )
    }
    if let startedAt = retainer.startsAt {
        events.append(
            RetainerActivityKind.accessStarted.event(
                at: startedAt,
                description: "Client access began."
            )
        )
    }
    if let endedAt = retainer.endsAt {
        events.append(
            RetainerActivityKind.accessEnded.event(
                at: endedAt,
                description: "Client access ended."
            )
        )
    }

    let attachments = try await RetainerProject.query(on: db)
        .filter(\.$retainer.$id == retainerID)
        .with(\.$project)
        .all()
    for rp in attachments {
        if let t = rp.insertedAt {
            events.append(
                RetainerActivityKind.projectAttached.event(
                    at: t,
                    description: "Project \(rp.project.codename) attached.",
                    href: "/admin/projects/\(rp.$project.id.uuidString)"
                )
            )
        }
    }

    return events.sorted { $0.timestamp > $1.timestamp }
}
