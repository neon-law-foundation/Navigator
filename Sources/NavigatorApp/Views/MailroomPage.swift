import Elementary
import Foundation
import NavigatorDAL
import NavigatorWeb

/// Tabular view of physical mail items received across every `Mailroom`.
///
/// Rendered identically at `/admin/mailroom` and `/portal/mailroom` until
/// authentication lands. Each row is one row of the `letters` table; the
/// mailroom column eager-loads `Letter.$mailroom` so the view never
/// triggers a per-row lookup.
struct MailroomPage: HTML {
    let brand: any Brand
    let portalLabel: String
    let letters: [Letter]

    var body: some HTML {
        PageLayout(
            pageTitle: "\(portalLabel) Mail Room",
            pageDescription:
                "Physical mail logged across every managed mailroom, newest first.",
            brand: brand
        ) {
            main(.class("max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                header(.class("mb-10")) {
                    p(.class("text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2")) {
                        portalLabel
                    }
                    h1(.class("text-4xl font-bold text-gray-900 mb-3")) { "Mail Room" }
                    p(.class("text-lg text-gray-600")) {
                        "Every piece of physical mail logged across every managed mailroom, "
                            + "newest first."
                    }
                }
                if letters.isEmpty {
                    EmptyState(brand: brand)
                } else {
                    LetterTable(letters: letters, brand: brand)
                }
            }
        }
    }
}

private struct LetterTable: HTML {
    let letters: [Letter]
    let brand: any Brand

    /// Renders the received-at column as the UTC calendar date only.
    /// Time-of-day is intentionally omitted — the page is a log of
    /// what arrived, not a delivery-timing dashboard.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var body: some HTML {
        div(.class("overflow-x-auto border border-gray-200 rounded-lg")) {
            table(.class("min-w-full divide-y divide-gray-200")) {
                thead(.class("bg-gray-50")) {
                    tr {
                        TableHeader(label: "Received")
                        TableHeader(label: "Mailroom")
                        TableHeader(label: "Mailbox")
                        TableHeader(label: "Sender")
                        TableHeader(label: "Subject")
                    }
                }
                tbody(.class("divide-y divide-gray-100 bg-white")) {
                    for letter in letters {
                        tr(.custom(name: "data-letter-id", value: letter.id?.uuidString ?? "")) {
                            TableCell {
                                Self.formattedDate(letter.receivedAt ?? letter.insertedAt)
                            }
                            TableCell { letter.mailroom.name }
                            TableCell {
                                letter.mailboxNumber.map(String.init) ?? "\u{2014}"
                            }
                            TableCell { letter.sender ?? "\u{2014}" }
                            TableCell { letter.subject ?? "\u{2014}" }
                        }
                    }
                }
            }
        }
    }

    private static func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "\u{2014}" }
        return dateFormatter.string(from: date)
    }
}

private struct TableHeader: HTML {
    let label: String

    var body: some HTML {
        th(
            .class(
                "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-600"
            )
        ) { label }
    }
}

private struct TableCell<Content: HTML>: HTML {
    @HTMLBuilder var content: () -> Content

    var body: some HTML {
        td(.class("px-4 py-3 text-sm text-gray-800 whitespace-nowrap")) {
            content()
        }
    }
}

private struct EmptyState: HTML {
    let brand: any Brand

    var body: some HTML {
        div(
            .class(
                "border border-dashed border-gray-300 rounded-lg p-12 text-center bg-gray-50"
            )
        ) {
            h2(.class("text-xl font-semibold text-gray-900 mb-2")) { "No mail yet" }
            p(.class("text-gray-600")) {
                "Letters scanned in at any managed mailroom will appear here."
            }
        }
    }
}
