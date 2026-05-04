import Testing

@testable import NavigatorWeb

@Suite("ChatInterface")
struct ChatInterfaceTests {
    private func userMessage(id: String = "u1", content: String = "What does the brief say?") -> ChatMessage {
        ChatMessage(id: id, role: .user, content: content)
    }

    private func assistantMessage(
        id: String = "a1",
        content: String = "The brief argues A.",
        citations: [Citation] = []
    ) -> ChatMessage {
        ChatMessage(id: id, role: .assistant, content: content, citations: citations)
    }

    @Test("renders the empty-state prompt when messages is empty")
    func rendersEmptyState() {
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: [],
            messages: [],
            sendPath: "/chat"
        ).render()

        #expect(html.contains("Ask a question about your documents."))
        #expect(html.contains(#"id="chat-log""#))
    }

    @Test("renders file-count badge with correct pluralization")
    func rendersContextCount() {
        let singular = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: ["f1"],
            messages: [],
            sendPath: "/chat"
        ).render()
        let plural = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: ["f1", "f2", "f3"],
            messages: [],
            sendPath: "/chat"
        ).render()

        #expect(singular.contains("1 file in context"))
        #expect(plural.contains("3 files in context"))
    }

    @Test("renders each context file id as a hidden input in the form")
    func rendersHiddenInputs() {
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: ["alpha", "bravo"],
            messages: [],
            sendPath: "/chat"
        ).render()

        #expect(html.contains(#"<input type="hidden" name="fileIds" value="alpha">"#))
        #expect(html.contains(#"<input type="hidden" name="fileIds" value="bravo">"#))
    }

    @Test("emits HTMX wire attributes on the form")
    func emitsHTMXAttributes() {
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: [],
            messages: [],
            sendPath: "/projects/123/chat"
        ).render()

        #expect(html.contains(#"hx-post="/projects/123/chat""#))
        #expect(html.contains("hx-target=\"#chat-log\""))
        #expect(html.contains(#"hx-swap="beforeend""#))
    }

    @Test("renders user messages right-aligned with brand color background")
    func rendersUserMessage() {
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: [],
            messages: [userMessage(content: "Hi.")],
            sendPath: "/chat"
        ).render()

        #expect(html.contains(#"<div class="flex flex-col gap-1 items-end">"#))
        #expect(html.contains(#"style="background-color:#00a651""#))
        #expect(html.contains(">Hi.</div>"))
    }

    @Test("renders assistant messages left-aligned without brand background")
    func rendersAssistantMessage() {
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: [],
            messages: [assistantMessage(content: "Hello.")],
            sendPath: "/chat"
        ).render()

        #expect(html.contains(#"<div class="flex flex-col gap-1 items-start">"#))
        #expect(
            html.contains(
                #"<div class="max-w-prose rounded-lg px-4 py-3 text-sm leading-relaxed bg-gray-100 text-gray-800">Hello.</div>"#
            )
        )
    }

    @Test("wraps citations in a details/summary disclosure block")
    func rendersCitationDetails() {
        let msg = assistantMessage(
            content: "See doc.",
            citations: [
                Citation(documentId: "d1", documentName: "Motion to Dismiss", passage: "In re Jones."),
                Citation(documentId: "d2", documentName: "Reply Brief", passage: "Contra, in Smith."),
            ]
        )
        let html = ChatInterface(
            brandColor: "#7c3aed",
            contextFileIds: [],
            messages: [msg],
            sendPath: "/chat"
        ).render()

        #expect(html.contains("<details"))
        #expect(html.contains("<summary"))
        #expect(html.contains("2 citations"))
        #expect(html.contains("Motion to Dismiss"))
        #expect(html.contains("Reply Brief"))
        #expect(html.contains("\u{201C}In re Jones.\u{201D}"))
        #expect(html.contains("\u{201C}Contra, in Smith.\u{201D}"))
    }

    @Test("uses singular citation label when exactly one citation is present")
    func citationPluralization() {
        let msg = assistantMessage(
            citations: [Citation(documentId: "d1", documentName: "Brief", passage: "Quote.")]
        )
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: [],
            messages: [msg],
            sendPath: "/chat"
        ).render()

        #expect(html.contains("1 citation<"))
    }

    @Test("omits the details block when assistant message has no citations")
    func omitsCitationDetailsWhenEmpty() {
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: [],
            messages: [assistantMessage(citations: [])],
            sendPath: "/chat"
        ).render()

        #expect(!html.contains("<details"))
        #expect(!html.contains("<summary"))
    }

    @Test("marks textarea and button as disabled when disabled is true")
    func rendersDisabledForm() {
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: [],
            messages: [],
            sendPath: "/chat",
            disabled: true
        ).render()

        // Two disabled attributes — one per form control.
        let disabledCount = html.components(separatedBy: "disabled=\"disabled\"").count - 1
        #expect(disabledCount == 2)
    }

    @Test("renders nothing disabled by default")
    func defaultIsEnabled() {
        let html = ChatInterface(
            brandColor: "#00a651",
            contextFileIds: [],
            messages: [],
            sendPath: "/chat"
        ).render()

        #expect(!html.contains("disabled=\"disabled\""))
    }
}
