import Elementary
import Foundation
import NavigatorDAL
import NavigatorWeb

/// `/admin/inbox` — list of inbound `EmailMessage` rows received at the
/// firm's support mailbox.
struct InboxIndexPage: HTML {
    let brand: any Brand
    let messages: [EmailMessage]
    let flash: String?
    let sort: SortSpec
    let filter: String
    let pagination: AdminPagination

    static let sortableKeys: Set<String> = ["receivedAt", "from", "subject"]
    static let defaultSort: SortSpec = .single("receivedAt", .descending)

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func sorted(_ messages: [EmailMessage], by spec: SortSpec) -> [EmailMessage] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return messages.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "receivedAt":
                return a.receivedAt < b.receivedAt
            case "from":
                let aFrom = (a.fromName ?? a.fromAddress).lowercased()
                let bFrom = (b.fromName ?? b.fromAddress).lowercased()
                return aFrom < bFrom
            case "subject":
                return a.subject.localizedCaseInsensitiveCompare(b.subject) == .orderedAscending
            default:
                return false
            }
        }
    }

    static func filtered(_ messages: [EmailMessage], by query: String) -> [EmailMessage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return messages }
        return messages.filter {
            $0.subject.lowercased().contains(trimmed)
                || $0.fromAddress.lowercased().contains(trimmed)
                || ($0.fromName?.lowercased().contains(trimmed) ?? false)
        }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Inbox",
            activeSection: .inbox,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    let unread = messages.filter { $0.acknowledgedAt == nil }.count
                    "\(messages.count) message\(messages.count == 1 ? "" : "s") · \(unread) unread"
                }
                p(.class("text-xs text-gray-500")) {
                    "Inbound mail is ingested by the SES pipeline; the inbox surface is read-only with an acknowledge action."
                }
            }
            AdminFlashBanner(message: flash)
            AdminFilterBar(
                action: "/admin/inbox",
                value: filter,
                placeholder: "Subject or sender\u{2026}"
            )
            if messages.isEmpty {
                div(
                    .class(
                        "rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white"
                    )
                ) {
                    p(.class("text-gray-600")) {
                        filter.isEmpty
                            ? "No inbound mail yet."
                            : "No messages matched \u{201C}\(filter)\u{201D}."
                    }
                }
            } else {
                form(
                    .action("/admin/inbox/acknowledge-bulk"),
                    .method(.post)
                ) {
                    div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                        table(.class("min-w-full divide-y divide-gray-200")) {
                            thead(.class("bg-gray-50")) {
                                tr {
                                    AdminTableHeader("")
                                    AdminSortableTH(
                                        "Received",
                                        key: "receivedAt",
                                        sort: sort,
                                        basePath: "/admin/inbox",
                                        queryItems: queryItems
                                    )
                                    AdminSortableTH(
                                        "From",
                                        key: "from",
                                        sort: sort,
                                        basePath: "/admin/inbox",
                                        queryItems: queryItems
                                    )
                                    AdminSortableTH(
                                        "Subject",
                                        key: "subject",
                                        sort: sort,
                                        basePath: "/admin/inbox",
                                        queryItems: queryItems
                                    )
                                    AdminTableHeader("Ack")
                                }
                            }
                            tbody(.class("divide-y divide-gray-100")) {
                                for m in messages {
                                    tr(
                                        .custom(
                                            name: "data-acknowledged",
                                            value: m.acknowledgedAt == nil ? "false" : "true"
                                        )
                                    ) {
                                        td(.class("px-4 py-3 text-sm w-8")) {
                                            input(
                                                .type(.checkbox),
                                                .name("ids[]"),
                                                .value(m.id?.uuidString ?? "")
                                            )
                                        }
                                        td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                            Self.dateFormatter.string(from: m.receivedAt)
                                        }
                                        td(.class("px-4 py-3 text-sm text-gray-700")) {
                                            m.fromName ?? m.fromAddress
                                        }
                                        td(.class("px-4 py-3 text-sm")) {
                                            a(
                                                .href("/admin/inbox/\(m.id?.uuidString ?? "")"),
                                                .class("text-indigo-700 hover:underline")
                                            ) { m.subject }
                                        }
                                        td(.class("px-4 py-3 text-sm")) {
                                            if m.acknowledgedAt == nil {
                                                span(.class("text-amber-700")) { "unread" }
                                            } else {
                                                span(.class("text-gray-400")) { "read" }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    div(.class("flex justify-end mt-4")) {
                        SubmitButton("Acknowledge selected", variant: .primary)
                    }
                }
                AdminPaginationFooter(pagination: pagination)
            }
        }
    }
}

/// `/admin/inbox/:id` — show a single email plus the acknowledge form,
/// reply / forward shortcuts, and the rest of the conversation thread.
struct InboxShowPage: HTML {
    let brand: any Brand
    let message: EmailMessage
    let thread: [EmailMessage]

    private var messageID: String { message.id?.uuidString ?? "" }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: message.subject,
            activeSection: .inbox,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/inbox"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to inbox"
                }
                div(.class("flex items-center gap-2")) {
                    LinkButton(
                        "Reply",
                        href: "/admin/messages/new?reply_to=\(messageID)",
                        variant: .primary
                    )
                    LinkButton(
                        "Forward",
                        href: "/admin/messages/new?forward=\(messageID)"
                    )
                    if message.acknowledgedAt == nil {
                        FormLayout(
                            action: "/admin/inbox/\(messageID)/acknowledge",
                            method: .post
                        ) {
                            SubmitButton("Mark as read")
                        }
                    } else {
                        span(.class("text-sm text-gray-500")) { "Acknowledged" }
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "From" }
                    dd(.class("text-gray-900")) {
                        if let name = message.fromName {
                            "\(name) <\(message.fromAddress)>"
                        } else {
                            message.fromAddress
                        }
                    }
                    dt(.class("text-gray-500")) { "To" }
                    dd(.class("text-gray-900")) { message.toAddress }
                    dt(.class("text-gray-500")) { "Subject" }
                    dd(.class("text-gray-900")) { message.subject }
                    dt(.class("text-gray-500")) { "Received" }
                    dd(.class("font-mono text-gray-700")) {
                        InboxIndexPage.dateFormatter.string(from: message.receivedAt)
                    }
                    dt(.class("text-gray-500")) { "SES verdicts" }
                    dd(.class("font-mono text-xs text-gray-700")) {
                        "spam:\(message.spamVerdict) virus:\(message.virusVerdict) dkim:\(message.dkimVerdict) dmarc:\(message.dmarcVerdict)"
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Body" }
                if let text = message.textBody, !text.isEmpty {
                    pre(.class("text-sm text-gray-800 whitespace-pre-wrap")) { text }
                } else if let html = message.htmlBody, !html.isEmpty {
                    pre(.class("text-xs text-gray-700 whitespace-pre-wrap break-all")) { html }
                } else {
                    p(.class("text-sm text-gray-500")) { "(no body)" }
                }
            }
            MessageThreadSection(thread: thread, currentMessageID: message.id)
        }
    }
}
