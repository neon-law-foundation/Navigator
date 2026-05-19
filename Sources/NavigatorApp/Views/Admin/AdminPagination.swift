import Elementary

/// Pagination state for an admin index page.
///
/// Captures the page index (`page`, 1-indexed), the page size, and the
/// total row count so the footer can render an accurate `Showing N–M
/// of T` line. Empty `total` renders nothing.
struct AdminPagination: Sendable {
    let page: Int
    let pageSize: Int
    let total: Int
    let basePath: String
    /// Extra query items round-tripped through Prev/Next links so
    /// sort + filter survive across pages. Same shape as
    /// ``NavigatorWeb/DataTable``'s `queryItems`.
    let queryItems: [(String, String)]

    /// Page-size cap admin index pages default to. Modeled on what a
    /// human can scan in one screen without virtualization.
    static let defaultPageSize = 50

    /// 1-indexed start row on this page.
    var startIndex: Int {
        total == 0 ? 0 : (page - 1) * pageSize + 1
    }

    /// 1-indexed end row on this page (clamped to `total`).
    var endIndex: Int {
        min(page * pageSize, total)
    }

    /// Whether there is a page after the current one.
    var hasNext: Bool { endIndex < total }

    /// Whether there is a page before the current one.
    var hasPrev: Bool { page > 1 && total > 0 }

    /// Parse a `?page=` query value, clamping to `>= 1`.
    static func parsePage(_ raw: String?) -> Int {
        guard let raw, let page = Int(raw), page > 0 else { return 1 }
        return page
    }

    /// Slice `rows` to the current page's window. Returns an empty
    /// array if the page is out of range.
    static func slice<Row>(_ rows: [Row], page: Int, pageSize: Int = defaultPageSize) -> [Row] {
        guard page > 0 else { return [] }
        let start = (page - 1) * pageSize
        guard start < rows.count else { return [] }
        let end = min(start + pageSize, rows.count)
        return Array(rows[start..<end])
    }
}

/// Renders the Prev/Next footer for an admin index page.
struct AdminPaginationFooter: HTML {
    let pagination: AdminPagination

    var body: some HTML {
        if pagination.total > pagination.pageSize {
            div(
                .class("flex items-center justify-between mt-4 text-sm text-gray-600"),
                .custom(name: "data-pagination", value: "true")
            ) {
                p {
                    "Showing \(pagination.startIndex)\u{2013}\(pagination.endIndex) of \(pagination.total)"
                }
                div(.class("flex items-center gap-3")) {
                    if pagination.hasPrev {
                        a(
                            .href(buildHref(page: pagination.page - 1)),
                            .class("text-indigo-700 hover:underline")
                        ) { "\u{2039} Prev" }
                    } else {
                        span(.class("text-gray-400")) { "\u{2039} Prev" }
                    }
                    if pagination.hasNext {
                        a(
                            .href(buildHref(page: pagination.page + 1)),
                            .class("text-indigo-700 hover:underline")
                        ) { "Next \u{203A}" }
                    } else {
                        span(.class("text-gray-400")) { "Next \u{203A}" }
                    }
                }
            }
        }
    }

    /// Builds an absolute URL with the target page plus any extra
    /// query items (sort + filter) in deterministic order.
    private func buildHref(page: Int) -> String {
        let extras = pagination.queryItems
            .filter { !$0.1.isEmpty }
            .sorted { $0.0 < $1.0 }
        var parts: [String] = []
        for (name, value) in extras {
            let encoded =
                value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            parts.append("\(name)=\(encoded)")
        }
        parts.append("page=\(page)")
        return "\(pagination.basePath)?\(parts.joined(separator: "&"))"
    }
}
