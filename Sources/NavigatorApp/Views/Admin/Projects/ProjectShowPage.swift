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
    let availablePeople: [Person]
    let assignmentError: String?
    let documentError: String?
    let activity: [AdminActivityEvent]

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
                div(.class("flex items-center gap-2")) {
                    LinkButton(
                        "Send message",
                        href: "/admin/messages/new?project_id=\(projectID)"
                    )
                    LinkButton(
                        "Edit",
                        href: "/admin/projects/\(projectID)/edit",
                        variant: .primary
                    )
                }
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
                if let assignmentError {
                    FormErrors([assignmentError])
                }
                if assignments.isEmpty {
                    p(.class("text-sm text-gray-500 mb-4")) {
                        "No people assigned to this project yet."
                    }
                } else {
                    ul(.class("space-y-2 text-sm mb-6")) {
                        for assignment in assignments {
                            li(
                                .class("flex items-center justify-between"),
                                .custom(name: "data-role", value: assignment.role.rawValue),
                                .custom(
                                    name: "data-person-id",
                                    value: assignment.$person.id.uuidString
                                )
                            ) {
                                div {
                                    span(.class("font-medium text-gray-900")) {
                                        assignment.person.name
                                    }
                                    span(.class("text-gray-500")) {
                                        " — \(assignment.role.rawValue)"
                                    }
                                }
                                FormLayout(
                                    action:
                                        "/admin/projects/\(projectID)/assignments/\(assignment.id?.uuidString ?? "")",
                                    method: .delete
                                ) {
                                    button(
                                        .type(.submit),
                                        .class("text-xs text-red-600 hover:underline")
                                    ) { "Remove" }
                                }
                            }
                        }
                    }
                }
                div(.class("border-t border-gray-200 pt-4")) {
                    p(.class("text-sm font-medium text-gray-700 mb-2")) { "Assign a person" }
                    FormLayout(
                        action: "/admin/projects/\(projectID)/assignments",
                        method: .post
                    ) {
                        div(.class("grid grid-cols-2 gap-3")) {
                            SelectField(
                                name: "personId",
                                label: "Person",
                                options: availablePeople.map {
                                    SelectOption(
                                        value: $0.id?.uuidString ?? "",
                                        label: $0.name
                                    )
                                },
                                required: true,
                                includeBlank: true,
                                blankLabel: "Pick a person\u{2026}"
                            )
                            SelectField(
                                ProjectRole.self,
                                name: "role",
                                label: "Role",
                                required: true
                            )
                        }
                        SubmitButton("Assign", variant: .primary)
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Documents" }
                if documentError != nil {
                    FormErrors([documentError ?? ""])
                }
                if documents.isEmpty {
                    p(.class("text-sm text-gray-500 mb-4")) {
                        "No documents on this project."
                    }
                } else {
                    ul(.class("space-y-2 text-sm mb-6")) {
                        for doc in documents {
                            li(
                                .class("flex items-center justify-between"),
                                .custom(
                                    name: "data-document-id",
                                    value: doc.id?.uuidString ?? ""
                                )
                            ) {
                                a(
                                    .href("/admin/documents/\(doc.id?.uuidString ?? "")/download"),
                                    .class("text-indigo-700 hover:underline")
                                ) { doc.title }
                                FormLayout(
                                    action: "/admin/documents/\(doc.id?.uuidString ?? "")",
                                    method: .delete
                                ) {
                                    button(
                                        .type(.submit),
                                        .class("text-xs text-red-600 hover:underline")
                                    ) { "Remove" }
                                }
                            }
                        }
                    }
                }
                div(.class("border-t border-gray-200 pt-4")) {
                    p(.class("text-sm font-medium text-gray-700 mb-2")) { "Upload a document" }
                    FormLayout(
                        action: "/admin/projects/\(projectID)/documents",
                        method: .post,
                        encoding: .multipart
                    ) {
                        TextField(
                            name: "title",
                            label: "Title",
                            required: true
                        )
                        div(.class("mb-4")) {
                            Elementary.label(
                                .for("field-file"),
                                .class("block text-sm font-medium text-gray-700 mb-1")
                            ) { "File" }
                            input(
                                .id("field-file"),
                                .name("file"),
                                .type(.file),
                                .required,
                                .class("block w-full text-sm")
                            )
                        }
                        SubmitButton("Upload", variant: .primary)
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
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
            AdminActivitySection(
                events: activity,
                emptyMessage: "No activity recorded for this project yet."
            )
        }
    }
}
