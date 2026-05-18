import Testing

@testable import NavigatorWeb

@Suite("DataTable")
struct DataTableTests {
    private struct FixtureRow: Sendable {
        let name: String
        let count: Int
    }

    private var columns: [DataTableColumn<FixtureRow>] {
        [
            DataTableColumn(key: "name", label: "Name") { $0.name },
            DataTableColumn(key: "count", label: "Count") { String($0.count) },
            DataTableColumn(key: "static", label: "Static", isSortable: false) { _ in "\u{2014}" },
        ]
    }

    private var rows: [FixtureRow] {
        [FixtureRow(name: "Alpha", count: 1), FixtureRow(name: "Beta", count: 2)]
    }

    @Test("renders the empty-state message and no <table> when rows is empty")
    func emptyState() {
        let html = DataTable<FixtureRow>(
            columns: columns,
            rows: [],
            sort: SortSpec(),
            basePath: "/things",
            emptyMessage: "Nothing here yet."
        ).render()

        #expect(html.contains("Nothing here yet."))
        #expect(!html.contains("<table"))
    }

    @Test("renders one <td> per column per row in column order")
    func rowCells() {
        let html = DataTable<FixtureRow>(
            columns: columns,
            rows: rows,
            sort: SortSpec(),
            basePath: "/things"
        ).render()

        #expect(html.contains(">Alpha<"))
        #expect(html.contains(">Beta<"))
        #expect(html.contains(">1<"))
        #expect(html.contains(">2<"))
        // Non-sortable column still has its cell rendered.
        #expect(html.contains(">\u{2014}<"))
    }

    @Test("sortable headers are anchor links pointing at basePath?sort=key")
    func sortableHeaderHasLink() {
        let html = DataTable<FixtureRow>(
            columns: columns,
            rows: rows,
            sort: SortSpec(),
            basePath: "/things"
        ).render()

        // No active sort yet, so the first click moves "name" to ascending.
        #expect(html.contains("href=\"/things?sort=name\""))
        #expect(html.contains("href=\"/things?sort=count\""))
    }

    @Test("non-sortable header is plain text, not a link")
    func staticHeaderHasNoLink() {
        let html = DataTable<FixtureRow>(
            columns: columns,
            rows: rows,
            sort: SortSpec(),
            basePath: "/things"
        ).render()

        // The static column's key is "static"; no href should reference it.
        #expect(!html.contains("?sort=static"))
        // The label still appears.
        #expect(html.contains(">Static<"))
    }

    @Test("clicking the active ascending column links to its descending form")
    func togglesActiveSortDirection() {
        let html = DataTable<FixtureRow>(
            columns: columns,
            rows: rows,
            sort: .single("name", .ascending),
            basePath: "/things"
        ).render()

        // Active column's link flips to descending.
        #expect(html.contains("href=\"/things?sort=-name\""))
        // Inactive sortable column links to its plain ascending form.
        #expect(html.contains("href=\"/things?sort=count\""))
    }

    @Test("active sort column renders its direction arrow")
    func activeArrow() {
        let html = DataTable<FixtureRow>(
            columns: columns,
            rows: rows,
            sort: .single("name", .descending),
            basePath: "/things"
        ).render()

        #expect(html.contains(SortDirection.descending.arrow))
    }

    @Test("inactive sortable columns do not render an arrow")
    func inactiveNoArrow() {
        let html = DataTable<FixtureRow>(
            columns: columns,
            rows: rows,
            sort: .single("name", .ascending),
            basePath: "/things"
        ).render()

        // Only one arrow should appear — the active column's.
        let ascending = SortDirection.ascending.arrow
        let occurrences = html.components(separatedBy: ascending).count - 1
        #expect(occurrences == 1)
    }

    @Test("data-column-key attribute is set on every header for testability")
    func headerHasColumnKeyAttribute() {
        let html = DataTable<FixtureRow>(
            columns: columns,
            rows: rows,
            sort: SortSpec(),
            basePath: "/things"
        ).render()

        #expect(html.contains("data-column-key=\"name\""))
        #expect(html.contains("data-column-key=\"count\""))
        #expect(html.contains("data-column-key=\"static\""))
    }
}
