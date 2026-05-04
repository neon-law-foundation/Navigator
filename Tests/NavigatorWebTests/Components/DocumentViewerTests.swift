import Testing

@testable import NavigatorWeb

@Suite("DocumentViewer")
struct DocumentViewerTests {
    @Test("renders empty-state prompt when file is nil")
    func rendersEmptyState() {
        let html = DocumentViewer(
            brandColor: "#00a651",
            file: nil
        ).render()

        let expected = """
            <div class="flex-1 flex items-center justify-center text-gray-400 text-sm">\
            Select a document to view its contents.\
            </div>
            """

        #expect(html == expected)
    }

    @Test("renders plain text file body in a whitespace-preserving pre block")
    func rendersTextFile() {
        let file = WorkshopFile(
            id: "f1",
            name: "intake-note.txt",
            category: "Intake",
            content: "Line one.\nLine two."
        )
        let html = DocumentViewer(brandColor: "#00a651", file: file).render()

        #expect(html.contains(#"<h2 class="text-lg font-semibold text-gray-800">intake-note.txt</h2>"#))
        #expect(html.contains(">Intake</p>"))
        #expect(
            html.contains(
                #"<pre class="p-6 whitespace-pre-wrap font-mono text-sm text-gray-700 leading-relaxed">"#
            )
        )
        #expect(html.contains("Line one.\nLine two."))
    }

    @Test("renders markdown content through the shared markdown pipeline")
    func rendersMarkdownFile() {
        let file = WorkshopFile(
            id: "f2",
            name: "brief.md",
            category: "Pleadings",
            content: "# Heading\n\nPara."
        )
        let html = DocumentViewer(brandColor: "#7c3aed", file: file).render()

        #expect(html.contains(#"<div class="p-6 prose prose-sm max-w-none text-gray-700">"#))
        #expect(html.contains("<h1>Heading</h1>"))
        #expect(html.contains("<p>Para.</p>"))
        // Text code path must not run.
        #expect(!html.contains(#"<pre class="p-6 whitespace-pre-wrap"#))
    }

    @Test("honours explicit markdown contentType over suffix detection")
    func honoursExplicitContentType() {
        let file = WorkshopFile(
            id: "f3",
            name: "note.txt",
            category: "Notes",
            content: "**bold**",
            contentType: .markdown
        )
        let html = DocumentViewer(brandColor: "#00a651", file: file).render()

        #expect(html.contains("<strong>bold</strong>"))
    }

    @Test("renders PDF files as an iframe pointing at the URL")
    func rendersPDFInIframe() {
        let file = WorkshopFile(
            id: "f4",
            name: "filing.pdf",
            category: "Filings",
            url: "https://example.com/doc.pdf"
        )
        let html = DocumentViewer(brandColor: "#00a651", file: file).render()

        #expect(
            html.contains(
                #"<iframe src="https://example.com/doc.pdf" class="w-full h-full border-0" title="filing.pdf">"#
            )
        )
    }

    @Test("renders a placeholder when PDF has no URL")
    func rendersPDFPlaceholder() {
        let file = WorkshopFile(
            id: "f5",
            name: "missing.pdf",
            category: "Filings"
        )
        let html = DocumentViewer(brandColor: "#00a651", file: file).render()

        #expect(html.contains("PDF has no URL to render."))
        #expect(!html.contains("<iframe"))
    }

    @Test("renders a placeholder when non-PDF file has no content")
    func rendersContentPlaceholder() {
        let file = WorkshopFile(id: "f6", name: "empty.md", category: "Notes")
        let html = DocumentViewer(brandColor: "#00a651", file: file).render()

        #expect(html.contains("No content available."))
    }

    @Test("renders highlight snippets in an aside when highlights are provided")
    func rendersHighlightsAside() {
        let file = WorkshopFile(
            id: "f7",
            name: "statute.md",
            category: "Statutes",
            content: "The quick brown fox jumps over the lazy dog."
        )
        let highlights = [
            DocumentHighlight(start: 4, end: 9),  // "quick"
            DocumentHighlight(start: 16, end: 19),  // "fox"
        ]
        let html = DocumentViewer(
            brandColor: "#00a651",
            file: file,
            highlights: highlights
        ).render()

        #expect(html.contains("<aside"))
        #expect(html.contains("Highlighted Passages"))
        #expect(html.contains(">quick</p>"))
        #expect(html.contains(">fox</p>"))
        #expect(html.contains(#"style="border-color:#00a651""#))
    }

    @Test("omits the highlight aside when highlights are empty")
    func hidesAsideWhenHighlightsEmpty() {
        let file = WorkshopFile(
            id: "f8",
            name: "statute.md",
            category: "Statutes",
            content: "Content."
        )
        let html = DocumentViewer(
            brandColor: "#00a651",
            file: file,
            highlights: []
        ).render()

        #expect(!html.contains("<aside"))
        #expect(!html.contains("Highlighted Passages"))
    }

    @Test("ignores highlights for PDF files")
    func ignoresHighlightsForPDF() {
        let file = WorkshopFile(
            id: "f9",
            name: "filing.pdf",
            category: "Filings",
            url: "https://example.com/doc.pdf"
        )
        let html = DocumentViewer(
            brandColor: "#00a651",
            file: file,
            highlights: [DocumentHighlight(start: 0, end: 3)]
        ).render()

        #expect(!html.contains("<aside"))
    }

    @Test("clamps highlight offsets to valid range")
    func clampsHighlightOffsets() {
        let file = WorkshopFile(
            id: "f10",
            name: "short.md",
            category: "Notes",
            content: "abc"
        )
        let html = DocumentViewer(
            brandColor: "#00a651",
            file: file,
            highlights: [
                DocumentHighlight(start: -5, end: 2),
                DocumentHighlight(start: 1, end: 99),
                DocumentHighlight(start: 2, end: 1),  // end < start → empty
            ]
        ).render()

        #expect(html.contains(">ab</p>"))
        #expect(html.contains(">bc</p>"))
        #expect(
            html.contains(
                #"<p class="text-xs text-gray-600 leading-relaxed border-l-2 pl-3" style="border-color:#00a651"></p>"#
            )
        )
    }

    @Test("propagates brand color to category chip and aside border")
    func propagatesBrandColor() {
        let file = WorkshopFile(
            id: "f11",
            name: "brief.md",
            category: "Pleadings",
            content: "Body."
        )
        let html = DocumentViewer(
            brandColor: "#7c3aed",
            file: file,
            highlights: [DocumentHighlight(start: 0, end: 4)]
        ).render()

        #expect(html.contains(#"style="color:#7c3aed""#))
        #expect(html.contains(#"style="border-color:#7c3aed""#))
    }
}
