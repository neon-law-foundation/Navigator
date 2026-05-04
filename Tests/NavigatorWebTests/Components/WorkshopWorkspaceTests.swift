import Testing

@testable import NavigatorWeb

@Suite("WorkshopWorkspace")
struct WorkshopWorkspaceTests {
    private let pleading = WorkshopFile(
        id: "p1",
        name: "motion.md",
        category: "Pleadings",
        content: "# Motion\n\nBody."
    )
    private let statute = WorkshopFile(
        id: "s1",
        name: "nrs-1.md",
        category: "Statutes",
        content: "Statutory text."
    )
    private let correspondence = WorkshopFile(
        id: "c1",
        name: "letter.md",
        category: "Pleadings",
        content: "Dear counsel."
    )

    private func workspace(
        activeFileId: String? = nil,
        highlights: [DocumentHighlight] = [],
        messages: [ChatMessage] = [],
        chatDisabled: Bool = false
    ) -> WorkshopWorkspace {
        WorkshopWorkspace(
            brandColor: "#00a651",
            files: [pleading, correspondence, statute],
            activeFileId: activeFileId,
            filesBasePath: "/workshops/demo",
            highlights: highlights,
            contextFileIds: ["p1", "s1"],
            messages: messages,
            sendPath: "/workshops/demo/chat",
            chatDisabled: chatDisabled
        )
    }

    // MARK: - WorkshopFileSidebar composition

    @Test("renders file sidebar with files grouped by category in first-seen order")
    func groupsFilesByCategory() {
        let html = workspace().render()

        // "Pleadings" appears before "Statutes" because the first pleading
        // precedes the first statute in the input order.
        let pleadingsIndex = html.range(of: ">Pleadings<")?.lowerBound
        let statutesIndex = html.range(of: ">Statutes<")?.lowerBound
        #expect(pleadingsIndex != nil)
        #expect(statutesIndex != nil)
        if let pleadingsIndex, let statutesIndex {
            #expect(pleadingsIndex < statutesIndex)
        }
        // Both pleading files fall under the same group.
        #expect(html.contains(#"href="/workshops/demo?file=p1""#))
        #expect(html.contains(#"href="/workshops/demo?file=c1""#))
        #expect(html.contains(#"href="/workshops/demo?file=s1""#))
    }

    @Test("marks the active file with aria-current and brand background")
    func marksActiveFile() {
        let html = workspace(activeFileId: "p1").render()

        #expect(
            html.contains(
                #"<a href="/workshops/demo?file=p1" class="block px-4 py-2 text-sm text-white font-medium" style="background-color:#00a651" aria-current="page">motion.md</a>"#
            )
        )
        // Other files keep the hover style.
        #expect(
            html.contains(
                #"<a href="/workshops/demo?file=c1" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors">letter.md</a>"#
            )
        )
    }

    @Test("emits no active state when activeFileId does not match any file")
    func noActiveStateWhenUnmatched() {
        let html = workspace(activeFileId: "nope").render()

        #expect(!html.contains("aria-current=\"page\""))
    }

    // MARK: - DocumentViewer composition

    @Test("renders the empty-viewer prompt when no file is active")
    func rendersEmptyViewer() {
        let html = workspace(activeFileId: nil).render()

        #expect(html.contains("Select a document to view its contents."))
    }

    @Test("resolves activeFileId to the matching file and renders its content")
    func resolvesActiveFile() {
        let html = workspace(activeFileId: "s1").render()

        #expect(html.contains("<h2 class=\"text-lg font-semibold text-gray-800\">nrs-1.md</h2>"))
        #expect(html.contains(">Statutes</p>"))
        #expect(html.contains("Statutory text."))
    }

    @Test("passes highlights through to DocumentViewer for non-PDF files")
    func passesHighlightsThrough() {
        let html = workspace(
            activeFileId: "s1",
            highlights: [DocumentHighlight(start: 0, end: 9)]
        ).render()

        #expect(html.contains("<aside"))
        #expect(html.contains(">Statutory</p>"))
    }

    // MARK: - ChatInterface composition

    @Test("renders the chat form with the supplied sendPath and context file ids")
    func composesChatInterface() {
        let html = workspace().render()

        #expect(html.contains(#"hx-post="/workshops/demo/chat""#))
        #expect(html.contains("hx-target=\"#chat-log\""))
        #expect(html.contains(#"<input type="hidden" name="fileIds" value="p1">"#))
        #expect(html.contains(#"<input type="hidden" name="fileIds" value="s1">"#))
        #expect(html.contains("2 files in context"))
    }

    @Test("propagates chatDisabled through to the ChatInterface")
    func propagatesChatDisabled() {
        let html = workspace(chatDisabled: true).render()

        #expect(html.contains("disabled=\"disabled\""))
    }

    @Test("renders supplied chat messages inside the chat-log")
    func rendersChatMessages() {
        let messages = [
            ChatMessage(id: "m1", role: .user, content: "Question?"),
            ChatMessage(
                id: "m2",
                role: .assistant,
                content: "Answer.",
                citations: [Citation(documentId: "s1", documentName: "nrs-1.md", passage: "Statute.")]
            ),
        ]
        let html = workspace(messages: messages).render()

        #expect(html.contains("Question?"))
        #expect(html.contains("Answer."))
        #expect(html.contains("<details"))
    }

    // MARK: - Overall layout

    @Test("wraps the three panes in a flex-row workshop-workspace container")
    func rendersThreePaneContainer() {
        let html = workspace(activeFileId: "p1").render()

        #expect(
            html.hasPrefix(
                #"<div class="workshop-workspace flex h-full w-full overflow-hidden bg-gray-50">"#
            )
        )
        #expect(html.contains(#"class="workshop-file-sidebar"#))
        #expect(html.contains(#"<div class="flex-1 flex overflow-hidden">"#))
        #expect(html.contains(#"<div class="w-96 border-l border-gray-200 flex-shrink-0">"#))
    }
}
