import Elementary
import NavigatorDAL
import NavigatorWeb

struct EntitiesIndexPage: HTML {
    let brand: any Brand
    let entities: [Entity]
    let flash: String?

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Entities",
            activeSection: .entities,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(entities.count) entit\(entities.count == 1 ? "y" : "ies")"
                }
                LinkButton("New entity", href: "/admin/entities/new", variant: .primary)
            }
            AdminFlashBanner(message: flash)
            if entities.isEmpty {
                AdminEmptyState(
                    message: "No entities yet. ",
                    ctaHref: "/admin/entities/new",
                    ctaLabel: "Add the first one."
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Name")
                                AdminTableHeader("Type")
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for entity in entities {
                                tr(.custom(name: "data-entity-id", value: entity.id?.uuidString ?? "")) {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/entities/\(entity.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { entity.name }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        entity.legalEntityType.name
                                    }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/entities/\(entity.id?.uuidString ?? "")/edit"),
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

struct EntityFormPage: HTML {
    enum Mode: Sendable {
        case new
        case edit(id: String)
    }

    let brand: any Brand
    let mode: Mode
    let form: EntityFormValues
    let errors: EntityFormErrors
    let entityTypes: [EntityType]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: mode.pageTitle,
            activeSection: .entities,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: mode.formAction, method: mode.formMethod) {
                    TextField(
                        name: "name",
                        label: "Name",
                        value: form.name,
                        required: true,
                        error: errors.name
                    )
                    SelectField(
                        name: "legalEntityTypeId",
                        label: "Entity type",
                        options: entityTypes.map {
                            SelectOption(
                                value: $0.id?.uuidString ?? "",
                                label: "\($0.name) (\($0.jurisdiction.code))"
                            )
                        },
                        selected: form.legalEntityTypeId,
                        required: true,
                        includeBlank: true,
                        blankLabel: "Pick a type\u{2026}",
                        error: errors.legalEntityTypeId
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(mode.submitLabel, variant: .primary)
                        LinkButton("Cancel", href: "/admin/entities")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        p(.class("text-sm text-gray-600 mb-2")) { "Destructive actions" }
                        ConfirmDeleteForm(
                            action: "/admin/entities/\(id)",
                            label: "Delete entity"
                        )
                    }
                }
            }
        }
    }
}

extension EntityFormPage.Mode {
    var pageTitle: String {
        switch self {
        case .new: "New entity"
        case .edit: "Edit entity"
        }
    }

    var formAction: String {
        switch self {
        case .new: "/admin/entities"
        case .edit(let id): "/admin/entities/\(id)"
        }
    }

    var formMethod: FormMethod {
        switch self {
        case .new: .post
        case .edit: .patch
        }
    }

    var submitLabel: String {
        switch self {
        case .new: "Create entity"
        case .edit: "Save changes"
        }
    }
}

struct EntityShowPage: HTML {
    let brand: any Brand
    let entity: Entity
    let people: [PersonEntityRole]
    let availablePeople: [Person]
    let assignmentError: String?

    private var entityID: String { entity.id?.uuidString ?? "" }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: entity.name,
            activeSection: .entities,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/entities"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to entities"
                }
                LinkButton("Edit", href: "/admin/entities/\(entityID)/edit", variant: .primary)
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Name" }
                    dd(.class("text-gray-900")) { entity.name }
                    dt(.class("text-gray-500")) { "Type" }
                    dd(.class("text-gray-900")) { entity.legalEntityType.name }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "People" }
                if let assignmentError {
                    FormErrors([assignmentError])
                }
                if people.isEmpty {
                    p(.class("text-sm text-gray-500 mb-4")) {
                        "No people on this entity yet."
                    }
                } else {
                    ul(.class("space-y-2 text-sm mb-6")) {
                        for role in people {
                            li(
                                .class("flex items-center justify-between"),
                                .custom(name: "data-role", value: role.role.rawValue),
                                .custom(
                                    name: "data-person-id",
                                    value: role.$person.id.uuidString
                                )
                            ) {
                                div {
                                    a(
                                        .href("/admin/people/\(role.$person.id.uuidString)"),
                                        .class("text-indigo-700 hover:underline")
                                    ) { role.person.name }
                                    span(.class("text-gray-500")) {
                                        " — \(role.role.rawValue)"
                                    }
                                }
                                FormLayout(
                                    action:
                                        "/admin/entities/\(entityID)/roles/\(role.id?.uuidString ?? "")",
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
                    p(.class("text-sm font-medium text-gray-700 mb-2")) {
                        "Assign a person"
                    }
                    FormLayout(
                        action: "/admin/entities/\(entityID)/roles",
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
                                PersonEntityRoleType.self,
                                name: "role",
                                label: "Role",
                                required: true
                            )
                        }
                        SubmitButton("Assign", variant: .primary)
                    }
                }
            }
        }
    }
}

struct EntityFormValues: Sendable {
    let name: String
    let legalEntityTypeId: String

    init(name: String = "", legalEntityTypeId: String = "") {
        self.name = name
        self.legalEntityTypeId = legalEntityTypeId
    }

    init(entity: Entity) {
        self.name = entity.name
        self.legalEntityTypeId = entity.$legalEntityType.id.uuidString
    }
}

struct EntityFormErrors: Sendable {
    let name: String?
    let legalEntityTypeId: String?
    let summary: [String]

    init(name: String? = nil, legalEntityTypeId: String? = nil, summary: [String] = []) {
        self.name = name
        self.legalEntityTypeId = legalEntityTypeId
        self.summary = summary
    }

    static let none = EntityFormErrors()
}
