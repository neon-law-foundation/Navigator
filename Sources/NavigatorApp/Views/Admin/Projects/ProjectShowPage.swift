import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/projects/:id` — detail view for a single project.
///
/// Renders the project's own fields plus the relationships an operator
/// needs to act on: staff and client assignments (PersonProjectRole),
/// documents, and git repositories. Each list is rendered inline; the
/// per-resource sub-CRUDs live on their own pages.
struct ProjectShowPage: HTML {
    let brand: any Brand
    let project: Project
    let assignments: [PersonProjectRole]
    let documents: [Document]
    let gitRepositories: [GitRepository]

    private var projectID: String { project.id?.uuidString ?? "" }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: project.codename,
            activeSection: .projects,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/projects"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to projects"
                }
                LinkButton("Edit", href: "/admin/projects/\(projectID)/edit", variant: .primary)
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Codename" }
                    dd(.class("font-mono text-gray-900")) { project.codename }
                    dt(.class("text-gray-500")) { "Title" }
                    dd(.class("text-gray-900")) { project.title ?? "\u{2014}" }
                    dt(.class("text-gray-500")) { "Status" }
                    dd(.class("text-gray-900")) { project.status?.rawValue ?? "\u{2014}" }
                    dt(.class("text-gray-500")) { "Type" }
                    dd(.class("text-gray-900")) { project.projectType?.rawValue ?? "\u{2014}" }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "People" }
                if assignments.isEmpty {
                    p(.class("text-sm text-gray-500")) { "No people assigned to this project yet." }
                } else {
                    ul(.class("space-y-2 text-sm")) {
                        for assignment in assignments {
                            li(.custom(name: "data-role", value: assignment.role.rawValue)) {
                                span(.class("font-medium text-gray-900")) { assignment.person.name }
                                span(.class("text-gray-500")) { " — \(assignment.role.rawValue)" }
                            }
                        }
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Documents" }
                if documents.isEmpty {
                    p(.class("text-sm text-gray-500")) { "No documents on this project." }
                } else {
                    ul(.class("space-y-1 text-sm")) {
                        for doc in documents {
                            li { doc.title }
                        }
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Git repositories" }
                if gitRepositories.isEmpty {
                    p(.class("text-sm text-gray-500")) { "No repositories linked." }
                } else {
                    ul(.class("space-y-1 text-sm font-mono")) {
                        for repo in gitRepositories {
                            li { repo.repositoryName }
                        }
                    }
                }
            }
        }
    }
}
