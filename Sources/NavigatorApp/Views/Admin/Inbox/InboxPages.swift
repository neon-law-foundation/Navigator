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

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

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
            if messages.isEmpty {
                div(
                    .class(
                        "rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white"
                    )
                ) {
                    p(.class("text-gray-600")) { "No inbound mail yet." }
                }
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Received")
                                AdminTableHeader("From")
                                AdminTableHeader("Subject")
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
            }
        }
    }
}

/// `/admin/inbox/:id` — show a single email plus the acknowledge form.
struct InboxShowPage: HTML {
    let brand: any Brand
    let message: EmailMessage

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
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Body" }
                if let text = message.textBody, !text.isEmpty {
                    pre(.class("text-sm text-gray-800 whitespace-pre-wrap")) { text }
                } else if let html = message.htmlBody, !html.isEmpty {
                    pre(.class("text-xs text-gray-700 whitespace-pre-wrap break-all")) { html }
                } else {
                    p(.class("text-sm text-gray-500")) { "(no body)" }
                }
            }
        }
    }
}
