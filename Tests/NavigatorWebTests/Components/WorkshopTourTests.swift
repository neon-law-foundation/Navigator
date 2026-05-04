import Testing

@testable import NavigatorWeb

@Suite("WorkshopTour")
struct WorkshopTourTests {
    private let steps = [
        TourStep(
            target: "#sidebar",
            content: "Pick a document here.",
            title: "Browse files"
        ),
        TourStep(
            target: ".chat-input",
            content: "Ask the assistant a question."
        ),
    ]

    @Test("renders an ordered list of step cards with titles and content")
    func rendersSteps() {
        let html = WorkshopTour(
            brandColor: "#00a651",
            steps: steps,
            startPath: "/workshops/demo/tour"
        ).render()

        #expect(html.contains("<ol"))
        #expect(html.contains(">Browse files</h3>"))
        #expect(html.contains("Pick a document here."))
        #expect(html.contains("Ask the assistant a question."))
    }

    @Test("renders each step's target selector as a monospace chip")
    func rendersTargetChips() {
        let html = WorkshopTour(
            brandColor: "#00a651",
            steps: steps,
            startPath: "/start"
        ).render()

        #expect(
            html.contains(
                #"<code class="px-1 py-0.5 bg-gray-100 rounded font-mono text-gray-700">#sidebar</code>"#
            )
        )
        #expect(
            html.contains(
                #"<code class="px-1 py-0.5 bg-gray-100 rounded font-mono text-gray-700">.chat-input</code>"#
            )
        )
    }

    @Test("renders a Start tour anchor pointing at startPath")
    func rendersStartTourAnchor() {
        let html = WorkshopTour(
            brandColor: "#00a651",
            steps: steps,
            startPath: "/workshops/demo/tour"
        ).render()

        #expect(html.contains(#"href="/workshops/demo/tour""#))
        #expect(html.contains(">Start tour</a>"))
    }

    @Test("renders the optional heading when provided")
    func rendersHeading() {
        let html = WorkshopTour(
            brandColor: "#7c3aed",
            steps: steps,
            startPath: "/start",
            heading: "Welcome to the workshop"
        ).render()

        #expect(html.contains(">Welcome to the workshop</h2>"))
    }

    @Test("omits the heading element when heading is nil")
    func omitsHeadingWhenNil() {
        let html = WorkshopTour(
            brandColor: "#00a651",
            steps: steps,
            startPath: "/start"
        ).render()

        #expect(!html.contains("<h2"))
    }

    @Test("renders a friendly empty-state message when steps is empty")
    func rendersEmptyState() {
        let html = WorkshopTour(
            brandColor: "#00a651",
            steps: [],
            startPath: "/start"
        ).render()

        #expect(html.contains("No tour steps available."))
        #expect(!html.contains("<ol"))
        #expect(!html.contains("Start tour"))
    }

    @Test("propagates brand color to heading, step titles, and start anchor")
    func propagatesBrandColor() {
        let html = WorkshopTour(
            brandColor: "#7c3aed",
            steps: steps,
            startPath: "/start",
            heading: "Tour"
        ).render()

        // At minimum: heading color, step-title color, and start anchor background.
        let occurrences = html.components(separatedBy: "#7c3aed").count - 1
        #expect(occurrences >= 3)
    }

    @Test("emits the workshop-tour aria-label on the section wrapper")
    func emitsAriaLabel() {
        let html = WorkshopTour(
            brandColor: "#00a651",
            steps: steps,
            startPath: "/start"
        ).render()

        #expect(html.hasPrefix(#"<section class="workshop-tour py-6" aria-label="Workshop tour">"#))
    }

    @Test("does not emit any JavaScript, localStorage, or overlay hooks")
    func carriesNoInteractivity() {
        let html = WorkshopTour(
            brandColor: "#00a651",
            steps: steps,
            startPath: "/start"
        ).render()

        #expect(!html.contains("<script"))
        #expect(!html.lowercased().contains("localstorage"))
        #expect(!html.lowercased().contains("joyride"))
    }
}
