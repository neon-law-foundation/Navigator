import Elementary
import NavigatorDAL
import NavigatorWeb

/// Mode for ``ProjectFormPage`` — controls the page title, the form's
/// action URL, and the HTTP verb the form submits.
enum ProjectFormMode: Sendable {
    /// Create a new project — `POST /admin/projects`.
    case new
    /// Update an existing project — `PATCH /admin/projects/:id`
    /// (via `_method=PATCH`).
    case edit(id: String)
}

/// Shared new/edit form for a project.
///
/// One page covers both paths because the field set is identical; only
/// the form action and the HTTP verb differ. Each field reflects either
/// the value the operator typed on a failed submission (`form.codename`,
/// etc.) or the value already persisted on the row.
struct ProjectFormPage: HTML {
    let brand: any Brand
    let mode: ProjectFormMode
    let form: ProjectFormValues
    let errors: ProjectFormErrors

    var pageTitle: String {
        switch mode {
        case .new: "New project"
        case .edit: "Edit project"
        }
    }

    var formAction: String {
        switch mode {
        case .new: "/admin/projects"
        case .edit(let id): "/admin/projects/\(id)"
        }
    }

    var formMethod: FormMethod {
        switch mode {
        case .new: .post
        case .edit: .patch
        }
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: pageTitle,
            activeSection: .projects,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: formAction, method: formMethod) {
                    TextField(
                        name: "codename",
                        label: "Codename",
                        value: form.codename,
                        required: true,
                        helpText: "Short, unique handle for this project.",
                        error: errors.codename
                    )
                    TextField(
                        name: "title",
                        label: "Title",
                        value: form.title,
                        helpText: "Human-readable project name (optional).",
                        error: errors.title
                    )
                    SelectField(
                        ProjectStatus.self,
                        name: "status",
                        label: "Status",
                        selected: form.statusEnum,
                        includeBlank: true,
                        blankLabel: "(none)",
                        error: errors.status
                    )
                    SelectField(
                        ProjectType.self,
                        name: "projectType",
                        label: "Project type",
                        selected: form.projectTypeEnum,
                        includeBlank: true,
                        blankLabel: "(none)",
                        error: errors.projectType
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(
                            mode.submitLabel,
                            variant: .primary
                        )
                        LinkButton("Cancel", href: "/admin/projects")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        p(.class("text-sm text-gray-600 mb-2")) {
                            "Destructive actions"
                        }
                        ConfirmDeleteForm(
                            action: "/admin/projects/\(id)",
                            label: "Delete project",
                            confirmMessage: "Delete this project? This cannot be undone."
                        )
                    }
                }
            }
        }
    }
}

extension ProjectFormMode {
    fileprivate var submitLabel: String {
        switch self {
        case .new: "Create project"
        case .edit: "Save changes"
        }
    }
}

/// Form values flowing through the new/edit lifecycle.
///
/// All fields are strings because that is what the form submits and what
/// the page needs to re-render on error. The `…Enum` accessors lift the
/// raw status / type strings back into the typed enum so the select
/// component can highlight the right option.
struct ProjectFormValues: Sendable {
    let codename: String
    let title: String
    let status: String
    let projectType: String

    init(
        codename: String = "",
        title: String = "",
        status: String = "",
        projectType: String = ""
    ) {
        self.codename = codename
        self.title = title
        self.status = status
        self.projectType = projectType
    }

    init(project: Project) {
        self.codename = project.codename
        self.title = project.title ?? ""
        self.status = project.status?.rawValue ?? ""
        self.projectType = project.projectType?.rawValue ?? ""
    }

    var statusEnum: ProjectStatus? { ProjectStatus(rawValue: status) }
    var projectTypeEnum: ProjectType? { ProjectType(rawValue: projectType) }
}

/// Per-field validation errors plus a top-of-form summary line. Empty
/// strings sentinel "no error" — the form components hide the markup
/// when their `error` value is nil, so the page maps empty to nil before
/// passing in.
struct ProjectFormErrors: Sendable {
    let codename: String?
    let title: String?
    let status: String?
    let projectType: String?
    let summary: [String]

    init(
        codename: String? = nil,
        title: String? = nil,
        status: String? = nil,
        projectType: String? = nil,
        summary: [String] = []
    ) {
        self.codename = codename
        self.title = title
        self.status = status
        self.projectType = projectType
        self.summary = summary
    }

    static let none = ProjectFormErrors()
}
