import Testing

@testable import NavigatorWeb

@Suite("Markdown Tables")
struct MarkdownTablesTests {

    @Test("Plain GFM table renders thead/tbody with cells")
    func plainTable() {
        let source = """
            | a | b |
            | - | - |
            | 1 | 2 |
            """

        let html = renderMarkdown(source)
        #expect(html.contains("<table>"))
        #expect(html.contains("<thead><tr><th>a</th><th>b</th></tr></thead>"))
        #expect(html.contains("<tbody><tr><td>1</td><td>2</td></tr></tbody>"))
    }

    @Test("Column alignments emit text-align style on each header and cell")
    func columnAlignments() {
        let source = """
            | left | center | right |
            | :--- | :----: | ----: |
            | a    | b      | c     |
            """

        let html = renderMarkdown(source)
        // Headers
        #expect(html.contains(#"<th style="text-align: left;">left</th>"#))
        #expect(html.contains(#"<th style="text-align: center;">center</th>"#))
        #expect(html.contains(#"<th style="text-align: right;">right</th>"#))
        // Body cells inherit the same alignment per column.
        #expect(html.contains(#"<td style="text-align: left;">a</td>"#))
        #expect(html.contains(#"<td style="text-align: center;">b</td>"#))
        #expect(html.contains(#"<td style="text-align: right;">c</td>"#))
    }
}
