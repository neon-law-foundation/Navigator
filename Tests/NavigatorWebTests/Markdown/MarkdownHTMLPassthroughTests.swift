import Testing

@testable import NavigatorWeb

/// Verifies the escape-by-default policy for raw HTML in markdown source.
///
/// CommonMark permits raw HTML to pass through unchanged, but doing so is
/// unsafe for user-authored content (XSS via `<script>`, `<iframe>`, etc.).
/// Our renderer escapes both ``Markdown/HTMLBlock`` and ``Markdown/InlineHTML``
/// so the raw text is shown to the reader rather than executed by the browser.
@Suite("Markdown HTML Passthrough")
struct MarkdownHTMLPassthroughTests {

    @Test("Inline <script> tag in markdown is escaped, not executed")
    func inlineScriptIsEscaped() {
        let html = renderMarkdown("Hello <script>alert(1)</script> world")
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
        #expect(html.contains("&lt;/script&gt;"))
    }

    @Test("Block-level raw HTML is escaped, not emitted as raw markup")
    func blockScriptIsEscaped() {
        let source = """
            <script>alert(1)</script>
            """

        let html = renderMarkdown(source)
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
    }

    @Test("Inline <img onerror=…> is escaped")
    func imgWithOnerrorIsEscaped() {
        let html = renderMarkdown("text <img onerror=alert(1) src=x> more")
        #expect(!html.contains("<img"))
        #expect(html.contains("&lt;img"))
    }
}
