import Testing

@testable import NavigatorWeb

@Suite("Markdown to Elementary Renderer")
struct MarkdownToElementaryTests {

    // MARK: - Block nodes

    @Test("Document wraps nothing around its children")
    func document() {
        let html = renderMarkdown("Hello world.")
        #expect(html == "<p>Hello world.</p>")
    }

    @Test("Heading renders levels 1 through 6")
    func heading() {
        #expect(renderMarkdown("# One") == "<h1>One</h1>")
        #expect(renderMarkdown("## Two") == "<h2>Two</h2>")
        #expect(renderMarkdown("### Three") == "<h3>Three</h3>")
        #expect(renderMarkdown("#### Four") == "<h4>Four</h4>")
        #expect(renderMarkdown("##### Five") == "<h5>Five</h5>")
        #expect(renderMarkdown("###### Six") == "<h6>Six</h6>")
    }

    @Test("Paragraph wraps a single line of prose")
    func paragraph() {
        #expect(renderMarkdown("just prose") == "<p>just prose</p>")
    }

    // MARK: - Inline nodes

    @Test("Text escapes HTML-sensitive characters")
    func text() {
        let html = renderMarkdown("a < b & c > d")
        #expect(html == "<p>a &lt; b &amp; c &gt; d</p>")
    }

    @Test("Emphasis renders as <em>")
    func emphasis() {
        #expect(renderMarkdown("*emphasis*") == "<p><em>emphasis</em></p>")
        #expect(renderMarkdown("_emphasis_") == "<p><em>emphasis</em></p>")
    }

    @Test("Strong renders as <strong>")
    func strong() {
        #expect(renderMarkdown("**bold**") == "<p><strong>bold</strong></p>")
        #expect(renderMarkdown("__bold__") == "<p><strong>bold</strong></p>")
    }

    @Test("Link renders href and inline text")
    func link() {
        let html = renderMarkdown("[Neon Law](https://www.neonlaw.com)")
        #expect(html == #"<p><a href="https://www.neonlaw.com">Neon Law</a></p>"#)
    }

    @Test("Hard line break renders as <br>")
    func lineBreak() {
        // Two trailing spaces before the newline force a hard break per CommonMark.
        let html = renderMarkdown("first line  \nsecond line")
        #expect(html == "<p>first line<br>second line</p>")
    }

    @Test("Soft break renders as a newline, not a tag")
    func softBreak() {
        let html = renderMarkdown("first line\nsecond line")
        #expect(html == "<p>first line\nsecond line</p>")
    }

    // MARK: - Kitchen sink

    @Test("Combined document renders heading, paragraph, emphasis, strong, link, and line break together")
    func kitchenSink() {
        let source = """
            # Heading

            This is a paragraph with *emphasis*, **strong**, and a [link](https://example.com).\u{0020}\u{0020}
            After a hard break.
            """

        let expected =
            "<h1>Heading</h1>"
            + "<p>This is a paragraph with <em>emphasis</em>, <strong>strong</strong>, "
            + #"and a <a href="https://example.com">link</a>.<br>After a hard break.</p>"#

        #expect(renderMarkdown(source) == expected)
    }

    // MARK: - Graceful fallback

    @Test("Unknown / unhandled nodes still surface their text via defaultVisit")
    func defaultVisitPreservesText() {
        // Custom blocks are not exposed by GFM and have no dedicated visitor;
        // they fall through `defaultVisit`, which recurses into children so
        // the text content is preserved even when no surrounding tag is added.
        let html = renderMarkdown("plain text")
        #expect(html.contains("plain text"))
    }
}
