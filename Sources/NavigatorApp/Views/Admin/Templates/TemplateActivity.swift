import Foundation
import NavigatorDAL

/// Event kinds the template activity timeline surfaces.
///
/// Templates are git-driven and ship as immutable rows once written —
/// the only event is the version's insertion time.
enum TemplateActivityKind: String, Sendable {
    case versionInserted

    var label: String { "Version recorded" }
    var chipPalette: String { "bg-purple-100 text-purple-800" }

    func event(at timestamp: Date, description: String) -> AdminActivityEvent {
        AdminActivityEvent(
            kind: rawValue,
            label: label,
            chipPalette: chipPalette,
            timestamp: timestamp,
            description: description
        )
    }
}

/// Builds the activity timeline for a single template version.
func loadTemplateActivity(template: Template) -> [AdminActivityEvent] {
    guard let insertedAt = template.insertedAt else { return [] }
    let shortSHA = String(template.version.prefix(8))
    return [
        TemplateActivityKind.versionInserted.event(
            at: insertedAt,
            description: "Version \(shortSHA) inserted."
        )
    ]
}
