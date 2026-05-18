import Elementary
import Foundation
import NavigatorDAL
import NavigatorWeb

/// Tabular view of physical mail items received across every `Mailroom`.
///
/// Rendered at `/admin/mailroom` and `/portal/mailroom`. The route layer
/// hands the page the rows it has already sorted, plus the parsed
/// ``SortSpec`` — the page itself is purely presentational and forwards
/// both to ``NavigatorWeb/DataTable``.
struct MailroomPage: HTML {
    let brand: any Brand
    let portalLabel: String
    let basePath: String
    let letters: [Letter]
    let sort: SortSpec

    /// JSON:API sort keys exposed by this page. The route handler
    /// validates incoming `?sort=` values against this set and returns
    /// `400` on anything else, per the JSON:API 1.1 MUST.
    static let sortableKeys: Set<String> = [
        "receivedAt", "mailroom", "mailbox", "sender", "subject",
    ]

    /// Default sort applied when the request omits `?sort=`. Newest mail
    /// first — that is what an operator looking for what just arrived
    /// expects to see at the top of the page.
    static let defaultSort: SortSpec = .single("receivedAt", .descending)

    /// Column definitions consumed by ``NavigatorWeb/DataTable``. Each
    /// column's `key` doubles as the JSON:API sort field name and matches
    /// a case in ``sorted(_:by:)``.
    static let columns: [DataTableColumn<Letter>] = [
        DataTableColumn(key: "receivedAt", label: "Received") { letter in
            formattedDate(letter.receivedAt ?? letter.insertedAt)
        },
        DataTableColumn(key: "mailroom", label: "Mailroom") { letter in
            letter.mailroom.name
        },
        DataTableColumn(key: "mailbox", label: "Mailbox") { letter in
            letter.mailboxNumber.map(String.init) ?? "\u{2014}"
        },
        DataTableColumn(key: "sender", label: "Sender") { letter in
            letter.sender ?? "\u{2014}"
        },
        DataTableColumn(key: "subject", label: "Subject") { letter in
            letter.subject ?? "\u{2014}"
        },
    ]

    /// Sorts `letters` according to `spec`. Falls back to ``defaultSort``
    /// when `spec` is empty so a freshly-loaded page is still meaningful.
    /// Sorting is stable in Swift's standard library, so secondary fields
    /// could be added by extending the primary comparator without
    /// changing callers.
    static func sorted(_ letters: [Letter], by spec: SortSpec) -> [Letter] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return letters.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "receivedAt":
                let aDate = a.receivedAt ?? a.insertedAt ?? .distantPast
                let bDate = b.receivedAt ?? b.insertedAt ?? .distantPast
                return aDate < bDate
            case "mailroom":
                return a.mailroom.name.localizedCaseInsensitiveCompare(b.mailroom.name)
                    == .orderedAscending
            case "mailbox":
                return (a.mailboxNumber ?? Int.max) < (b.mailboxNumber ?? Int.max)
            case "sender":
                return (a.sender ?? "").localizedCaseInsensitiveCompare(b.sender ?? "")
                    == .orderedAscending
            case "subject":
                return (a.subject ?? "").localizedCaseInsensitiveCompare(b.subject ?? "")
                    == .orderedAscending
            default:
                return false
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "\u{2014}" }
        return dateFormatter.string(from: date)
    }

    var body: some HTML {
        PageLayout(
            pageTitle: "\(portalLabel) Mail Room",
            pageDescription:
                "Physical mail logged across every managed mailroom.",
            brand: brand
        ) {
            main(.class("max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                header(.class("mb-10")) {
                    p(.class("text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2")) {
                        portalLabel
                    }
                    h1(.class("text-4xl font-bold text-gray-900 mb-3")) { "Mail Room" }
                    p(.class("text-lg text-gray-600")) {
                        "Every piece of physical mail logged across every managed mailroom. "
                            + "Click a column header to sort."
                    }
                    if portalLabel == "Admin" {
                        div(.class("mt-4")) {
                            LinkButton(
                                "New letter",
                                href: "/admin/mailroom/letters/new",
                                variant: .primary
                            )
                        }
                    }
                }
                DataTable(
                    columns: Self.columns,
                    rows: letters,
                    sort: sort,
                    basePath: basePath,
                    emptyMessage:
                        "Letters scanned in at any managed mailroom will appear here."
                )
            }
        }
    }
}
