import Testing

@testable import NavigatorWeb

@Suite("ProjectSidebar")
struct ProjectSidebarTests {
    private let alpha = WebProject(id: "alpha", name: "Alpha Matter", href: "/projects/alpha")
    private let bravo = WebProject(id: "bravo", name: "Bravo Charter", href: "/projects/bravo")
    private let charlie = WebProject(id: "charlie", name: "Charlie Case", href: "/projects/charlie")

    @Test("renders every project as an anchor with its href and name")
    func rendersAllProjects() {
        let html = ProjectSidebar(
            projects: [alpha, bravo, charlie],
            selectedId: nil
        ).render()

        #expect(html.contains(#"href="/projects/alpha""#))
        #expect(html.contains(#"href="/projects/bravo""#))
        #expect(html.contains(#"href="/projects/charlie""#))
        #expect(html.contains("Alpha Matter"))
        #expect(html.contains("Bravo Charter"))
        #expect(html.contains("Charlie Case"))
    }

    @Test("applies the active class to the selected project only")
    func appliesActiveClassToSelected() {
        let html = ProjectSidebar(
            projects: [alpha, bravo, charlie],
            selectedId: "bravo"
        ).render()

        let expected = """
            <nav class="flex flex-col gap-1 py-4" aria-label="Projects">\
            <a href="/projects/alpha" \
            class="block rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"\
            >Alpha Matter</a>\
            <a href="/projects/bravo" \
            class="block rounded px-3 py-2 text-sm bg-gray-900 text-white font-semibold" \
            aria-current="page">Bravo Charter</a>\
            <a href="/projects/charlie" \
            class="block rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"\
            >Charlie Case</a>\
            </nav>
            """

        #expect(html == expected)
    }

    @Test("renders no active state when selectedId is nil")
    func noActiveStateWhenNil() {
        let html = ProjectSidebar(
            projects: [alpha, bravo],
            selectedId: nil
        ).render()

        #expect(!html.contains("aria-current"))
        #expect(!html.contains("bg-gray-900 text-white font-semibold"))
    }

    @Test("renders no active state when selectedId does not match any project")
    func noActiveStateWhenUnmatched() {
        let html = ProjectSidebar(
            projects: [alpha, bravo],
            selectedId: "zulu"
        ).render()

        #expect(!html.contains("aria-current"))
        #expect(!html.contains("bg-gray-900 text-white font-semibold"))
    }

    @Test("renders the nav wrapper but no items when projects is empty")
    func emptyProjects() {
        let html = ProjectSidebar(projects: [], selectedId: nil).render()

        let expected = """
            <nav class="flex flex-col gap-1 py-4" aria-label="Projects"></nav>
            """

        #expect(html == expected)
    }
}
