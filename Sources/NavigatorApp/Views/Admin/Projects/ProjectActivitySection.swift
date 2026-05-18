import Elementary
import Foundation

/// Timeline UI for ``ProjectActivityEvent`` rows. Renders newest-first
/// with a kind chip, a one-line description, and the timestamp. The
/// kind chip carries a `data-kind` attribute so route tests can assert
/// on what events the timeline contained without coupling to label
/// wording.
struct ProjectActivitySection: HTML {
    let events: [ProjectActivityEvent]

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some HTML {
        section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
            h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Activity" }
            if events.isEmpty {
                p(.class("text-sm text-gray-500")) {
                    "No activity recorded for this project yet."
                }
            } else {
                ol(.class("space-y-3")) {
                    for event in events {
                        li(
                            .class("flex items-start gap-3"),
                            .custom(name: "data-kind", value: event.kind.rawValue)
                        ) {
                            span(.class(chipClass(for: event.kind))) {
                                event.kind.label
                            }
                            div(.class("flex-1")) {
                                if let href = event.href {
                                    a(
                                        .href(href),
                                        .class("text-sm text-indigo-700 hover:underline")
                                    ) { event.description }
                                } else {
                                    p(.class("text-sm text-gray-800")) { event.description }
                                }
                                p(.class("text-xs font-mono text-gray-500")) {
                                    Self.formatter.string(from: event.timestamp)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Color-codes each event kind on the chip so the timeline reads
    /// quickly at a glance — create is green, update is blue, assignment
    /// is indigo, etc. All chips share a common chrome.
    private func chipClass(for kind: ProjectActivityKind) -> String {
        let base = "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
        let palette: String
        switch kind {
        case .created: palette = "bg-green-100 text-green-800"
        case .updated: palette = "bg-blue-100 text-blue-800"
        case .personAssigned: palette = "bg-indigo-100 text-indigo-800"
        case .documentAdded: palette = "bg-amber-100 text-amber-800"
        case .repositoryLinked: palette = "bg-purple-100 text-purple-800"
        case .disclosureFiled: palette = "bg-rose-100 text-rose-800"
        }
        return "\(base) \(palette)"
    }
}
