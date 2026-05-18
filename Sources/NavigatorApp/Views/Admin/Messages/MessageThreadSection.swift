import Elementary
import Foundation
import NavigatorDAL
import NavigatorWeb

/// Renders every `EmailMessage` row that shares a `thread_id` with the
/// page's current message, oldest-first, mixed inbound and outbound.
///
/// Used on both `/admin/inbox/:id` and `/admin/messages/:id` so an
/// operator can read the full conversation in one view without
/// hopping between the two surfaces. The current message is marked
/// `data-current="true"` so the route tests can pin which row the
/// operator is currently on.
struct MessageThreadSection: HTML {
    let thread: [EmailMessage]
    let currentMessageID: UUID?

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some HTML {
        section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
            h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Thread" }
            if thread.count <= 1 {
                p(.class("text-sm text-gray-500")) {
                    "No other messages in this conversation."
                }
            } else {
                ol(.class("space-y-3 text-sm")) {
                    for message in thread {
                        let isCurrent = message.id == currentMessageID
                        let directionLabel = message.direction == .inbound ? "Inbound" : "Outbound"
                        let href =
                            message.direction == .inbound
                            ? "/admin/inbox/\(message.id?.uuidString ?? "")"
                            : "/admin/messages/\(message.id?.uuidString ?? "")"
                        li(
                            .class(threadRowClasses(isCurrent: isCurrent)),
                            .custom(name: "data-direction", value: message.direction.rawValue),
                            .custom(name: "data-current", value: isCurrent ? "true" : "false")
                        ) {
                            div(.class("flex items-center justify-between mb-1")) {
                                span(.class("text-xs font-semibold uppercase tracking-wide text-gray-500")) {
                                    directionLabel
                                }
                                span(.class("text-xs font-mono text-gray-500")) {
                                    Self.dateFormatter.string(from: message.receivedAt)
                                }
                            }
                            if isCurrent {
                                p(.class("text-gray-900 font-medium")) { message.subject }
                            } else {
                                a(.href(href), .class("text-indigo-700 hover:underline font-medium")) {
                                    message.subject
                                }
                            }
                            p(.class("text-xs text-gray-600 mt-1")) {
                                "From \(message.fromAddress) to \(message.toAddress)"
                            }
                        }
                    }
                }
            }
        }
    }

    private func threadRowClasses(isCurrent: Bool) -> String {
        let base = "rounded-md border p-3"
        return isCurrent
            ? "\(base) border-indigo-300 bg-indigo-50"
            : "\(base) border-gray-200 bg-gray-50"
    }
}
