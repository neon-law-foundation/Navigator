import Testing

@testable import NavigatorWeb

/// Coverage for the inline nodes that landed in M3 step 2:
/// inline code, images, GFM strikethrough, and inline HTML.
@Suite("Markdown Inline Nodes")
struct MarkdownInlineNodesTests {

    @Test("Inline code renders as <code> with escaped contents")
    func inlineCode() {
        let html = renderMarkdown("Use `let x = 1` to bind.")
        #expect(html == "<p>Use <code>let x = 1</code> to bind.</p>")
    }

    @Test("Inline code escapes HTML-sensitive characters")
    func inlineCodeEscapes() {
        let html = renderMarkdown("`<b>`")
        #expect(html == "<p><code>&lt;b&gt;</code></p>")
    }

    @Test("Image renders src and alt")
    func image() {
        let html = renderMarkdown("![alt text](https://example.com/x.png)")
        #expect(html == #"<p><img src="https://example.com/x.png" alt="alt text"></p>"#)
    }

    @Test("Image with title renders src, alt, and title")
    func imageWithTitle() {
        let html = renderMarkdown(#"![alt](https://example.com/x.png "the title")"#)
        #expect(
            html == #"<p><img src="https://example.com/x.png" alt="alt" title="the title"></p>"#
        )
    }

    @Test("GFM strikethrough renders as <del>")
    func strikethrough() {
        let html = renderMarkdown("~~struck~~")
        #expect(html == "<p><del>struck</del></p>")
    }
}
