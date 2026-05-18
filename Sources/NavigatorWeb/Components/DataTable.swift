import Elementary

/// One column in a ``DataTable``.
///
/// `key` doubles as the JSON:API 1.1 `sort` field name — clicking a
/// sortable header issues a GET to `basePath?sort=<key>` (or `-<key>` to
/// flip direction). `cell` runs once per row to produce the cell's text
/// content; Elementary escapes the returned string automatically.
public struct DataTableColumn<Row>: Sendable where Row: Sendable {
    public let key: String
    public let label: String
    public let isSortable: Bool
    public let cell: @Sendable (Row) -> String

    public init(
        key: String,
        label: String,
        isSortable: Bool = true,
        cell: @escaping @Sendable (Row) -> String
    ) {
        self.key = key
        self.label = label
        self.isSortable = isSortable
        self.cell = cell
    }
}

/// Generic table view shared across pages.
///
/// Pages build a `[DataTableColumn<Row>]` describing their columns, pass
/// in the already-sorted rows plus the current ``SortSpec`` (the spec the
/// route handler parsed from `?sort=`), and the component renders a
/// JSON:API-compatible sortable table.
///
/// Sortable headers are real `<a>` links to the same page with a flipped
/// `?sort=` value, so sorting works without JavaScript and is trivially
/// testable through Vapor's in-process harness. HTMX-style in-place
/// swapping can later layer on top by adding `hx-*` attributes to the
/// same anchors — the link target stays the source of truth.
///
/// The component is purely presentational: it does not re-sort `rows`
/// and does not validate `sort` against the column allowlist. Callers
/// must do both before rendering (`SortSpec.validated(against:)` covers
/// the validation half).
///
/// `basePath` is treated as an opaque path-only string. Pass `/foo/bar`,
/// not `/foo/bar?other=x` — query string interpolation is unsafe and not
/// in scope for the v1 component.
public struct DataTable<Row>: HTML where Row: Sendable {
    public let columns: [DataTableColumn<Row>]
    public let rows: [Row]
    public let sort: SortSpec
    public let basePath: String
    public let emptyMessage: String
    /// Extra `(name, value)` pairs to round-trip through every sort link
    /// so a search filter (`?q=...`) survives a sort click. Encoded
    /// alphabetically once, before `sort=`, so the generated URLs are
    /// deterministic and easy to assert against.
    public let queryItems: [(String, String)]

    public init(
        columns: [DataTableColumn<Row>],
        rows: [Row],
        sort: SortSpec = SortSpec(),
        basePath: String,
        emptyMessage: String = "No rows.",
        queryItems: [(String, String)] = []
    ) {
        self.columns = columns
        self.rows = rows
        self.sort = sort
        self.basePath = basePath
        self.emptyMessage = emptyMessage
        self.queryItems = queryItems
    }

    public var body: some HTML {
        if rows.isEmpty {
            DataTableEmptyState(message: emptyMessage)
        } else {
            div(.class("overflow-x-auto border border-gray-200 rounded-lg")) {
                table(.class("min-w-full divide-y divide-gray-200")) {
                    thead(.class("bg-gray-50")) {
                        tr {
                            for column in columns {
                                DataTableHeader(
                                    column: column,
                                    sort: sort,
                                    basePath: basePath,
                                    queryItems: queryItems
                                )
                            }
                        }
                    }
                    tbody(.class("divide-y divide-gray-100 bg-white")) {
                        for row in rows {
                            tr {
                                for column in columns {
                                    td(
                                        .class(
                                            "px-4 py-3 text-sm text-gray-800 whitespace-nowrap"
                                        )
                                    ) { column.cell(row) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DataTableHeader<Row>: HTML where Row: Sendable {
    let column: DataTableColumn<Row>
    let sort: SortSpec
    let basePath: String
    let queryItems: [(String, String)]

    var body: some HTML {
        th(
            .class(
                "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-600"
            ),
            .custom(name: "data-column-key", value: column.key)
        ) {
            if column.isSortable {
                let nextSpec = sort.toggling(column.key)
                a(
                    .href(buildSortHref(nextSpec: nextSpec)),
                    .class("inline-flex items-center gap-1 hover:text-gray-900")
                ) {
                    column.label
                    if let direction = sort.direction(for: column.key) {
                        span(.class("text-gray-400")) { direction.arrow }
                    }
                }
            } else {
                column.label
            }
        }
    }

    /// Builds the per-header sort URL. Extra query items are sorted by
    /// name so the rendered HTML stays deterministic across iterations of
    /// `[(String, String)]`, then encoded ahead of `sort=` so the
    /// existing one-arg `?sort=…` parsing still works.
    private func buildSortHref(nextSpec: SortSpec) -> String {
        let sorted =
            queryItems
            .filter { !$0.1.isEmpty }
            .sorted { $0.0 < $1.0 }
        let extras = sorted.map { name, value in
            let encodedValue =
                value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(name)=\(encodedValue)"
        }
        let parts = extras + ["sort=\(nextSpec.encoded)"]
        return "\(basePath)?\(parts.joined(separator: "&"))"
    }
}

private struct DataTableEmptyState: HTML {
    let message: String

    var body: some HTML {
        div(
            .class(
                "border border-dashed border-gray-300 rounded-lg p-12 text-center bg-gray-50"
            )
        ) {
            p(.class("text-gray-600")) { message }
        }
    }
}
