import Elementary

/// Renders a vertical sidebar of project links for workshop views.
///
/// Selected state is determined server-side by comparing each project's
/// `id` against `selectedId`. The matching project receives a distinct
/// Tailwind class string and an `aria-current="page"` attribute; all
/// other entries render with the default hover-only styling. Passing
/// `selectedId: nil` — or an id that does not match any project — means
/// no active state is emitted. The component has no interactivity: URL
/// changes drive selection via a full page navigation or, later, an
/// HTMX swap initiated by the caller.
public struct ProjectSidebar: HTML {
    public let projects: [WebProject]
    public let selectedId: String?

    public init(projects: [WebProject], selectedId: String?) {
        self.projects = projects
        self.selectedId = selectedId
    }

    public var body: some HTML {
        nav(
            .class("flex flex-col gap-1 py-4"),
            .custom(name: "aria-label", value: "Projects")
        ) {
            for project in projects {
                if project.id == selectedId {
                    a(
                        .href(project.href),
                        .class(
                            "block rounded px-3 py-2 text-sm bg-gray-900 text-white font-semibold"
                        ),
                        .custom(name: "aria-current", value: "page")
                    ) { project.name }
                } else {
                    a(
                        .href(project.href),
                        .class(
                            "block rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
                        )
                    ) { project.name }
                }
            }
        }
    }
}
