import FluentKit
import Foundation
import NavigatorDAL

/// Event kinds the notation activity timeline surfaces.
enum NotationActivityKind: String, Sendable {
    case created
    case stateTransitioned

    var label: String {
        switch self {
        case .created: "Notation opened"
        case .stateTransitioned: "State transition"
        }
    }

    var chipPalette: String {
        switch self {
        case .created: "bg-green-100 text-green-800"
        case .stateTransitioned: "bg-indigo-100 text-indigo-800"
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

/// Builds the activity timeline for a notation. Pure derivation from
/// the `stateHistory` JSONB column and the row's own `insertedAt`.
func loadNotationActivity(notation: Notation) -> [AdminActivityEvent] {
    var events: [AdminActivityEvent] = []
    if let createdAt = notation.insertedAt {
        events.append(
            NotationActivityKind.created.event(
                at: createdAt,
                description: "Notation opened against \(notation.template.title)."
            )
        )
    }
    for evt in notation.stateHistory.value {
        let note = evt.note.map { " — \($0)" } ?? ""
        let description = "\(evt.fromState) \u{2192} \(evt.toState) via \(evt.condition)\(note)"
        events.append(
            NotationActivityKind.stateTransitioned.event(
                at: evt.at,
                description: description
            )
        )
    }
    return events.sorted { $0.timestamp > $1.timestamp }
}
