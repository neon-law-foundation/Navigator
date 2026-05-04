import Foundation
import Testing

@testable import NavigatorCLI

@Suite("Markdown Editor")
struct MarkdownEditorTests {

    @Test("Extracts front matter from markdown file")
    func testExtractFrontMatter() throws {
        let markdown = """
            ---
            title: Test Standard
            type: notation
            ---

            # Header

            This is content.
            """

        let (frontMatter, content) = try MarkdownEditor.parseFrontMatter(from: markdown)

        #expect(
            frontMatter == """
                ---
                title: Test Standard
                type: notation
                ---
                """
        )
        #expect(
            content == """

                # Header

                This is content.
                """
        )
    }

    @Test("Handles markdown without front matter")
    func testNoFrontMatter() throws {
        let markdown = """
            # Header

            This is content.
            """

        let (frontMatter, content) = try MarkdownEditor.parseFrontMatter(from: markdown)

        #expect(frontMatter == nil)
        #expect(content == markdown)
    }

    @Test("Joins lines within paragraphs")
    func testJoinParagraphLines() throws {
        let markdown = """
            This is a long
            paragraph that
            spans multiple
            lines.

            This is another
            paragraph.
            """

        let result = MarkdownEditor.transformForEditing(markdown)

        #expect(
            result == """
                This is a long paragraph that spans multiple lines.

                This is another paragraph.
                """
        )
    }

    @Test("Preserves headers on own lines")
    func testPreserveHeaders() throws {
        let markdown = """
            # Header 1

            ## Header 2

            ### Header 3
            """

        let result = MarkdownEditor.transformForEditing(markdown)

        #expect(
            result == """
                # Header 1

                ## Header 2

                ### Header 3
                """
        )
    }

    @Test("Preserves code blocks unchanged")
    func testPreserveCodeBlocks() throws {
        let markdown = """
            Some text.

            ```swift
            let x = 1
            let y = 2

            func test() {
                print("hello")
            }
            ```

            More text.
            """

        let result = MarkdownEditor.transformForEditing(markdown)

        #expect(
            result == """
                Some text.

                ```swift
                let x = 1
                let y = 2

                func test() {
                    print("hello")
                }
                ```

                More text.
                """
        )
    }

    @Test("Keeps bullet points on one line each")
    func testBulletPoints() throws {
        let markdown = """
            - First item that
              spans multiple lines
            - Second item
            - Third item that also
              spans lines
            """

        let result = MarkdownEditor.transformForEditing(markdown)

        #expect(
            result == """
                - First item that spans multiple lines
                - Second item
                - Third item that also spans lines
                """
        )
    }

    @Test("Keeps numbered lists on one line each")
    func testNumberedLists() throws {
        let markdown = """
            1. First item that
               spans multiple lines
            2. Second item
            3. Third item
            """

        let result = MarkdownEditor.transformForEditing(markdown)

        #expect(
            result == """
                1. First item that spans multiple lines
                2. Second item
                3. Third item
                """
        )
    }

    @Test("Preserves nested list indentation")
    func testNestedLists() throws {
        let markdown = """
            - Parent item
              - Nested item that
                spans lines
              - Another nested
            - Another parent
            """

        let result = MarkdownEditor.transformForEditing(markdown)

        #expect(
            result == """
                - Parent item
                  - Nested item that spans lines
                  - Another nested
                - Another parent
                """
        )
    }

    @Test("Handles mixed content")
    func testMixedContent() throws {
        let markdown = """
            # Introduction

            This is a paragraph
            that spans multiple
            lines.

            - Bullet one
              continues here
            - Bullet two

            ```python
            def hello():
                print("world")

            hello()
            ```

            ## Conclusion

            Final paragraph
            here.
            """

        let result = MarkdownEditor.transformForEditing(markdown)

        #expect(
            result == """
                # Introduction

                This is a paragraph that spans multiple lines.

                - Bullet one continues here
                - Bullet two

                ```python
                def hello():
                    print("world")

                hello()
                ```

                ## Conclusion

                Final paragraph here.
                """
        )
    }

    @Test("Extracts filename for temp path")
    func testTempPath() throws {
        let filePath = "/Users/test/standards/nevada.md"
        let tempPath = MarkdownEditor.tempPath(for: filePath)

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(tempPath == "\(homeDir)/.navigator/temp/nevada.pages")
    }

    @Test("Extracts filename from relative path")
    func testTempPathRelative() throws {
        let filePath = "standards/nevada.md"
        let tempPath = MarkdownEditor.tempPath(for: filePath)

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(tempPath == "\(homeDir)/.navigator/temp/nevada.pages")
    }
}
