import Elementary
import NavigatorDAL
import NavigatorWeb

/// Shared new/edit form mode for a person.
enum PersonFormMode: Sendable {
    case new
    case edit(id: String)
}

struct PersonFormPage: HTML {
    let brand: any Brand
    let mode: PersonFormMode
    let form: PersonFormValues
    let errors: PersonFormErrors

    var pageTitle: String {
        switch mode {
        case .new: "New person"
        case .edit: "Edit person"
        }
    }

    var formAction: String {
        switch mode {
        case .new: "/admin/people"
        case .edit(let id): "/admin/people/\(id)"
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
            activeSection: .people,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: formAction, method: formMethod) {
                    TextField(
                        name: "name",
                        label: "Name",
                        value: form.name,
                        required: true,
                        error: errors.name
                    )
                    EmailField(
                        name: "email",
                        label: "Email",
                        value: form.email,
                        required: true,
                        error: errors.email
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(
                            mode.submitLabel,
                            variant: .primary
                        )
                        LinkButton("Cancel", href: "/admin/people")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        p(.class("text-sm text-gray-600 mb-2")) { "Destructive actions" }
                        ConfirmDeleteForm(
                            action: "/admin/people/\(id)",
                            label: "Delete person",
                            confirmMessage: "Delete this person? This cannot be undone."
                        )
                    }
                }
            }
        }
    }
}

extension PersonFormMode {
    fileprivate var submitLabel: String {
        switch self {
        case .new: "Create person"
        case .edit: "Save changes"
        }
    }
}

struct PersonFormValues: Sendable {
    let name: String
    let email: String

    init(name: String = "", email: String = "") {
        self.name = name
        self.email = email
    }

    init(person: Person) {
        self.name = person.name
        self.email = person.email
    }
}

struct PersonFormErrors: Sendable {
    let name: String?
    let email: String?
    let summary: [String]

    init(name: String? = nil, email: String? = nil, summary: [String] = []) {
        self.name = name
        self.email = email
        self.summary = summary
    }

    static let none = PersonFormErrors()
}
