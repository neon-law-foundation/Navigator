import Elementary
import Foundation
import NavigatorDAL
import NavigatorWeb

/// `/admin/messages` — list of outbound `EmailMessage` rows.
///
/// Inbound mail is shown at `/admin/inbox`; this page filters to rows
/// whose ``EmailMessage/direction`` is `.outbound`.
struct MessagesIndexPage: HTML {
    let brand: any Brand
    let messages: [EmailMessage]
    let flash: String?
    let sort: SortSpec
    let filter: String
    let pagination: AdminPagination

    static let sortableKeys: Set<String> = ["sent", "to", "subject"]
    static let defaultSort: SortSpec = .single("sent", .descending)

    static func sorted(_ rows: [EmailMessage], by spec: SortSpec) -> [EmailMessage] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return rows.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "sent":
                return a.receivedAt < b.receivedAt
            case "to":
                return a.toAddress.localizedCaseInsensitiveCompare(b.toAddress)
                    == .orderedAscending
            case "subject":
                return a.subject.localizedCaseInsensitiveCompare(b.subject) == .orderedAscending
            default: return false
            }
        }
    }

    static func filtered(_ rows: [EmailMessage], by query: String) -> [EmailMessage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return rows }
        return rows.filter {
            $0.subject.lowercased().contains(trimmed)
                || $0.toAddress.lowercased().contains(trimmed)
        }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Messages",
            activeSection: .messages,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(messages.count) sent"
                }
                LinkButton("New message", href: "/admin/messages/new", variant: .primary)
            }
            AdminFlashBanner(message: flash)
            AdminFilterBar(
                action: "/admin/messages",
                value: filter,
                placeholder: "Subject or recipient\u{2026}"
            )
            if messages.isEmpty {
                AdminEmptyState(
                    message: filter.isEmpty
                        ? "No outbound messages yet. "
                        : "No messages matched \u{201C}\(filter)\u{201D}. ",
                    ctaHref: "/admin/messages/new",
                    ctaLabel: "Compose one."
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminSortableTH(
                                    "Sent",
                                    key: "sent",
                                    sort: sort,
                                    basePath: "/admin/messages",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "To",
                                    key: "to",
                                    sort: sort,
                                    basePath: "/admin/messages",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "Subject",
                                    key: "subject",
                                    sort: sort,
                                    basePath: "/admin/messages",
                                    queryItems: queryItems
                                )
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for m in messages {
                                tr(.custom(name: "data-message-id", value: m.id?.uuidString ?? "")) {
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                        MessageFormat.shortDateTime(m.receivedAt)
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) { m.toAddress }
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/messages/\(m.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { m.subject }
                                    }
                                }
                            }
                        }
                    }
                }
                AdminPaginationFooter(pagination: pagination)
            }
        }
    }
}

/// `/admin/messages/new` — compose form.
///
/// `replyContext` is non-nil when the operator arrived here via the
/// Reply button on an inbound message — its `inReplyTo` and
/// `parentThreadId` are emitted as hidden inputs so the POST handler can
/// thread the outbound row back into the inbound conversation.
struct MessageComposePage: HTML {
    let brand: any Brand
    let form: MessageFormValues
    let errors: MessageFormErrors
    let replyContext: MessageReplyContext?

    init(
        brand: any Brand,
        form: MessageFormValues,
        errors: MessageFormErrors,
        replyContext: MessageReplyContext? = nil
    ) {
        self.brand = brand
        self.form = form
        self.errors = errors
        self.replyContext = replyContext
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: replyContext == nil ? "New message" : "Reply",
            activeSection: .messages,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                if let replyContext {
                    p(.class("text-xs text-gray-500 mb-4")) {
                        "Replying to \u{201C}\(replyContext.originalSubject)\u{201D}"
                    }
                }
                FormLayout(action: "/admin/messages", method: .post) {
                    if let replyContext {
                        HiddenField(name: "inReplyTo", value: replyContext.inReplyTo)
                        HiddenField(name: "parentThreadId", value: replyContext.parentThreadId)
                    }
                    EmailField(
                        name: "to",
                        label: "To",
                        value: form.to,
                        required: true,
                        placeholder: "recipient@example.com",
                        error: errors.to
                    )
                    TextField(
                        name: "subject",
                        label: "Subject",
                        value: form.subject,
                        required: true,
                        error: errors.subject
                    )
                    TextArea(
                        name: "body",
                        label: "Body",
                        value: form.body,
                        rows: 10,
                        required: true,
                        error: errors.body
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton("Send", variant: .primary)
                        LinkButton("Cancel", href: "/admin/messages")
                    }
                }
            }
        }
    }
}

/// Hidden-input payload threaded through a reply form.
struct MessageReplyContext: Sendable {
    let inReplyTo: String
    let parentThreadId: String
    let originalSubject: String
}

/// `/admin/messages/:id` — single sent message plus the rest of the
/// conversation thread and a Reply shortcut that threads the next
/// outbound row back into the same conversation.
struct MessageShowPage: HTML {
    let brand: any Brand
    let message: EmailMessage
    let sendError: String?
    let thread: [EmailMessage]
    let replyTarget: EmailMessage?

    private var messageID: String { message.id?.uuidString ?? "" }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: message.subject,
            activeSection: .messages,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/messages"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to messages"
                }
                if let replyTarget {
                    LinkButton(
                        "Reply",
                        href: "/admin/messages/new?reply_to=\(replyTarget.id?.uuidString ?? "")",
                        variant: .primary
                    )
                }
            }
            if let sendError {
                div(
                    .class(
                        "mb-4 rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-800"
                    ),
                    .custom(name: "role", value: "alert")
                ) {
                    p(.class("font-medium")) { "The row was saved but the live send failed." }
                    p { sendError }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "From" }
                    dd(.class("text-gray-900")) { message.fromAddress }
                    dt(.class("text-gray-500")) { "To" }
                    dd(.class("text-gray-900")) { message.toAddress }
                    dt(.class("text-gray-500")) { "Subject" }
                    dd(.class("text-gray-900")) { message.subject }
                    dt(.class("text-gray-500")) { "Sent" }
                    dd(.class("font-mono text-gray-700")) {
                        MessageFormat.shortDateTime(message.receivedAt)
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Body" }
                pre(.class("text-sm text-gray-800 whitespace-pre-wrap")) {
                    message.textBody ?? "(empty)"
                }
            }
            MessageThreadSection(thread: thread, currentMessageID: message.id)
        }
    }
}

struct MessageFormValues: Sendable {
    let to: String
    let subject: String
    let body: String

    init(to: String = "", subject: String = "", body: String = "") {
        self.to = to
        self.subject = subject
        self.body = body
    }
}

struct MessageFormErrors: Sendable {
    let to: String?
    let subject: String?
    let body: String?
    let summary: [String]

    init(
        to: String? = nil,
        subject: String? = nil,
        body: String? = nil,
        summary: [String] = []
    ) {
        self.to = to
        self.subject = subject
        self.body = body
        self.summary = summary
    }

    static let none = MessageFormErrors()
}

/// Date formatter local to the messages pages so it does not collide with
/// the inbox formatter.
enum MessageFormat {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    static func shortDateTime(_ date: Date) -> String { formatter.string(from: date) }
}
