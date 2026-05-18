import Elementary
import NavigatorWeb

/// Sortable column header for admin index tables.
///
/// Wraps the same `?sort=…` toggle behavior ``NavigatorWeb/DataTable``
/// already implements, but emits just a single `<th>` so admin index
/// pages can keep their custom row markup (links, edit affordances)
/// while still getting JSON:API-style sortable headers.
///
/// `queryItems` round-trip alongside the sort so a `?q=` filter survives
/// a sort click — same contract as `DataTable(queryItems:)`.
struct AdminSortableTH: HTML {
    let key: String
    let label: String
    let sort: SortSpec
    let basePath: String
    let queryItems: [(String, String)]
    let alignment: AdminTableHeader.Alignment

    init(
        _ label: String,
        key: String,
        sort: SortSpec,
        basePath: String,
        queryItems: [(String, String)] = [],
        alignment: AdminTableHeader.Alignment = .left
    ) {
        self.label = label
        self.key = key
        self.sort = sort
        self.basePath = basePath
        self.queryItems = queryItems
        self.alignment = alignment
    }

    var body: some HTML {
        let nextSpec = sort.toggling(key)
        th(
            .class(
                "px-4 py-3 text-\(alignment == .right ? "right" : "left") text-xs font-semibold uppercase tracking-wide text-gray-600"
            ),
            .custom(name: "data-column-key", value: key)
        ) {
            a(
                .href(buildHref(nextSpec: nextSpec)),
                .class("inline-flex items-center gap-1 hover:text-gray-900")
            ) {
                label
                if let direction = sort.direction(for: key) {
                    span(.class("text-gray-400")) { direction.arrow }
                }
            }
        }
    }

    private func buildHref(nextSpec: SortSpec) -> String {
        let extras = queryItems.filter { !$0.1.isEmpty }.sorted { $0.0 < $1.0 }
        let encodedExtras = extras.map { name, value in
            let encoded =
                value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(name)=\(encoded)"
        }
        let parts = encodedExtras + ["sort=\(nextSpec.encoded)"]
        return "\(basePath)?\(parts.joined(separator: "&"))"
    }
}
