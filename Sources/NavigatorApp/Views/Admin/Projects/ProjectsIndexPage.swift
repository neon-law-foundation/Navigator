import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/projects` — list of every project, newest-updated first.
struct ProjectsIndexPage: HTML {
    let brand: any Brand
    let projects: [Project]
    let flash: String?

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Projects",
            activeSection: .projects,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(projects.count) project\(projects.count == 1 ? "" : "s")"
                }
                LinkButton("New project", href: "/admin/projects/new", variant: .primary)
            }
            if let flash {
                div(
                    .class("mb-4 rounded-md border border-green-300 bg-green-50 p-3 text-sm text-green-800"),
                    .custom(name: "role", value: "status")
                ) { flash }
            }
            if projects.isEmpty {
                div(.class("rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white")) {
                    p(.class("text-gray-600")) {
                        "No projects yet. "
                    }
                    a(.href("/admin/projects/new"), .class("text-indigo-600 hover:underline")) {
                        "Create the first one."
                    }
                }
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                th(
                                    .class(
                                        "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-600"
                                    )
                                ) { "Codename" }
                                th(
                                    .class(
                                        "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-600"
                                    )
                                ) { "Title" }
                                th(
                                    .class(
                                        "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-600"
                                    )
                                ) { "Status" }
                                th(
                                    .class(
                                        "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-600"
                                    )
                                ) { "Type" }
                                th(
                                    .class(
                                        "px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-600"
                                    )
                                ) { "" }
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for project in projects {
                                tr(.custom(name: "data-project-id", value: project.id?.uuidString ?? "")) {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/projects/\(project.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline font-mono")
                                        ) { project.codename }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        project.title ?? "\u{2014}"
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        project.status?.rawValue ?? "\u{2014}"
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        project.projectType?.rawValue ?? "\u{2014}"
                                    }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/projects/\(project.id?.uuidString ?? "")/edit"),
                                            .class("text-gray-600 hover:text-gray-900")
                                        ) { "Edit" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
