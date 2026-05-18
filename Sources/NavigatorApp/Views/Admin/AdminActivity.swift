import Elementary
import Foundation

/// One event on an admin activity timeline.
///
/// `kind` carries the raw discriminator used in tests
/// (`data-kind="…"`) so per-resource loaders can swap the displayed
/// label without breaking assertions. `chipPalette` is the Tailwind
/// color set drawn on the kind chip — also resource-specific.
struct AdminActivityEvent: Sendable {
    let kind: String
    let label: String
    let chipPalette: String
    let timestamp: Date
    let description: String
    let href: String?

    init(
        kind: String,
        label: String,
        chipPalette: String,
        timestamp: Date,
        description: String,
        href: String? = nil
    ) {
        self.kind = kind
        self.label = label
        self.chipPalette = chipPalette
        self.timestamp = timestamp
        self.description = description
        self.href = href
    }
}

/// Timeline UI shared by every admin show page that surfaces an
/// activity history (project, person, entity, …).
///
/// Each per-resource loader builds `[AdminActivityEvent]`; this section
/// renders them in receive order (callers sort newest-first before
/// passing in). Empty arrays render an empty-state note so the chrome
/// is consistent across resources.
struct AdminActivitySection: HTML {
    let events: [AdminActivityEvent]
    let emptyMessage: String

    init(events: [AdminActivityEvent], emptyMessage: String = "No activity recorded yet.") {
        self.events = events
        self.emptyMessage = emptyMessage
    }

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
                p(.class("text-sm text-gray-500")) { emptyMessage }
            } else {
                ol(.class("space-y-3")) {
                    for event in events {
                        li(
                            .class("flex items-start gap-3"),
                            .custom(name: "data-kind", value: event.kind)
                        ) {
                            span(
                                .class(
                                    "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium \(event.chipPalette)"
                                )
                            ) { event.label }
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
}
