import Testing

@testable import NavigatorWeb

@Suite("Markdown Lists")
struct MarkdownListsTests {

    @Test("Unordered list wraps each item in <li> inside <ul>")
    func unorderedList() {
        // swift-markdown's parser always represents list items as block
        // containers, so paragraph children render as <p>. This matches
        // cmark-gfm's output for any list whose items contain block content.
        let html = renderMarkdown("- one\n- two")
        #expect(html == "<ul><li><p>one</p></li><li><p>two</p></li></ul>")
    }

    @Test("Ordered list defaults to no start attribute")
    func orderedListDefault() {
        let html = renderMarkdown("1. one\n2. two")
        #expect(html == "<ol><li><p>one</p></li><li><p>two</p></li></ol>")
    }

    @Test("Ordered list with non-1 start emits start attribute")
    func orderedListWithStart() {
        let html = renderMarkdown("3. three\n4. four")
        #expect(
            html == #"<ol start="3"><li><p>three</p></li><li><p>four</p></li></ol>"#
        )
    }

    @Test("Nested unordered list renders the nested <ul> inside the parent <li>")
    func nestedList() {
        let source = """
            - parent
              - child
            """

        let html = renderMarkdown(source)
        // The outer <ul> wraps a single <li> whose body is "parent" plus the
        // nested <ul><li>child</li></ul>.
        #expect(
            html
                == "<ul><li><p>parent</p><ul><li><p>child</p></li></ul></li></ul>"
        )
    }

    @Test("Unchecked GFM task-list item renders disabled checkbox")
    func taskListUnchecked() {
        let html = renderMarkdown("- [ ] todo")
        #expect(html.contains(#"<input type="checkbox" disabled> "#))
        #expect(html.contains("todo"))
        // The checkbox sits inside the <li>, before the rest of the item body.
        #expect(html.hasPrefix(#"<ul><li><input type="checkbox" disabled> "#))
    }

    @Test("Checked GFM task-list item renders disabled+checked checkbox")
    func taskListChecked() {
        let html = renderMarkdown("- [x] done")
        #expect(html.contains(#"<input type="checkbox" disabled checked> "#))
        #expect(html.contains("done"))
        #expect(html.hasPrefix(#"<ul><li><input type="checkbox" disabled checked> "#))
    }
}
