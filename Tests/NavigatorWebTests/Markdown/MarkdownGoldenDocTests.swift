import Testing

@testable import NavigatorWeb

/// "Kitchen sink" snapshot covering every M3 step-2 construct in one document.
@Suite("Markdown Golden Document")
struct MarkdownGoldenDocTests {

    @Test("Combined fixture renders to the expected HTML string")
    func goldenDocument() {
        let source = """
            # Title

            Intro paragraph with `inline code`, ~~struck text~~, and an image
            ![alt](https://example.com/x.png).

            ```swift
            let x = 1
            ```

            > A quoted line.

            - parent
              - [x] done child
              - [ ] pending child

            | name | qty |
            | :--- | --: |
            | a    | 1   |
            """

        let expected =
            "<h1>Title</h1>"
            + "<p>Intro paragraph with <code>inline code</code>, "
            + "<del>struck text</del>, and an image\n"
            + #"<img src="https://example.com/x.png" alt="alt">.</p>"#
            + #"<pre><code class="language-swift">let x = 1\#n</code></pre>"#
            + "<blockquote><p>A quoted line.</p></blockquote>"
            + "<ul>"
            + "<li><p>parent</p>"
            + "<ul>"
            + #"<li><input type="checkbox" disabled checked> <p>done child</p></li>"#
            + #"<li><input type="checkbox" disabled> <p>pending child</p></li>"#
            + "</ul></li>"
            + "</ul>"
            + "<table>"
            + #"<thead><tr><th style="text-align: left;">name</th>"#
            + #"<th style="text-align: right;">qty</th></tr></thead>"#
            + #"<tbody><tr><td style="text-align: left;">a</td>"#
            + #"<td style="text-align: right;">1</td></tr></tbody>"#
            + "</table>"

        #expect(renderMarkdown(source) == expected)
    }
}
