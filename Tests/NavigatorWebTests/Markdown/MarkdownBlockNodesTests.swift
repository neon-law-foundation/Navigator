import Testing

@testable import NavigatorWeb

/// Coverage for the block-level nodes that landed in M3 step 2:
/// code blocks, blockquotes, thematic breaks, and HTML blocks.
@Suite("Markdown Block Nodes")
struct MarkdownBlockNodesTests {

    @Test("Code block without a language renders <pre><code>")
    func codeBlockNoLanguage() {
        let source = """
            ```
            let x = 1
            ```
            """

        #expect(renderMarkdown(source) == "<pre><code>let x = 1\n</code></pre>")
    }

    @Test("Code block with a language adds language-* class")
    func codeBlockWithLanguage() {
        let source = """
            ```swift
            let x = 1
            ```
            """

        #expect(renderMarkdown(source) == #"<pre><code class="language-swift">let x = 1\#n</code></pre>"#)
    }

    @Test("Code block escapes HTML-sensitive characters in its body")
    func codeBlockEscapesContent() {
        let source = """
            ```html
            <script>alert(1)</script>
            ```
            """

        #expect(
            renderMarkdown(source)
                == #"<pre><code class="language-html">&lt;script&gt;alert(1)&lt;/script&gt;\#n</code></pre>"#
        )
    }

    @Test("Blockquote wraps inline children")
    func blockquote() {
        let html = renderMarkdown("> a quote")
        #expect(html == "<blockquote><p>a quote</p></blockquote>")
    }

    @Test("Thematic break renders as <hr>")
    func thematicBreak() {
        #expect(renderMarkdown("---") == "<hr>")
    }
}
