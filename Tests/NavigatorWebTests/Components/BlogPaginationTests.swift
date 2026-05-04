import Testing

@testable import NavigatorWeb

@Suite("BlogPagination")
struct BlogPaginationTests {
    @Test("renders prev and next links on a middle page")
    func rendersPrevAndNextOnMiddle() {
        let html = BlogPagination(current: 2, total: 3, basePath: "/blog").render()

        #expect(html.contains(#"href="/blog?page=1""#))
        #expect(html.contains(#"href="/blog?page=3""#))
        #expect(html.contains("Previous"))
        #expect(html.contains("Next"))
    }

    @Test("disables prev on the first page")
    func disablesPrevOnFirstPage() {
        let html = BlogPagination(current: 1, total: 3, basePath: "/blog").render()

        // No anchor for prev — only a disabled span/marker.
        #expect(!html.contains(#"href="/blog?page=0""#))
        #expect(html.contains("aria-disabled=\"true\""))
        #expect(html.contains(#"href="/blog?page=2""#))
    }

    @Test("disables next on the last page")
    func disablesNextOnLastPage() {
        let html = BlogPagination(current: 3, total: 3, basePath: "/blog").render()

        #expect(html.contains(#"href="/blog?page=2""#))
        #expect(!html.contains(#"href="/blog?page=4""#))
        #expect(html.contains("aria-disabled=\"true\""))
    }

    @Test("disables both prev and next when total is 1")
    func disablesBothWhenSinglePage() {
        let html = BlogPagination(current: 1, total: 1, basePath: "/blog").render()

        #expect(!html.contains(#"href="/blog?page="#))
        // Two disabled markers — one for prev, one for next.
        let disabledOpens = html.components(separatedBy: "aria-disabled=\"true\"").count - 1
        #expect(disabledOpens == 2)
    }

    @Test("uses the supplied basePath in generated query strings")
    func usesBasePath() {
        let html = BlogPagination(current: 2, total: 4, basePath: "/news").render()

        #expect(html.contains(#"href="/news?page=1""#))
        #expect(html.contains(#"href="/news?page=3""#))
    }
}
