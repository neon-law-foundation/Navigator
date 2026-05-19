import Elementary
import NavigatorDAL
import NavigatorWeb

/// Shared new/edit form for a share class.
struct ShareClassFormPage: HTML {
    enum Mode: Sendable {
        case new
        case edit(id: String)
    }

    let brand: any Brand
    let mode: Mode
    let form: ShareClassFormValues
    let errors: ShareClassFormErrors
    let entities: [Entity]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: mode.pageTitle,
            activeSection: .shareClasses,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: mode.formAction, method: mode.formMethod) {
                    SelectField(
                        name: "entityId",
                        label: "Entity",
                        options: entities.map {
                            SelectOption(value: $0.id?.uuidString ?? "", label: $0.name)
                        },
                        selected: form.entityId,
                        required: true,
                        includeBlank: true,
                        blankLabel: "Pick an entity\u{2026}",
                        error: errors.entityId
                    )
                    TextField(
                        name: "name",
                        label: "Name",
                        value: form.name,
                        required: true,
                        error: errors.name
                    )
                    TextField(
                        name: "priority",
                        label: "Priority",
                        value: form.priority,
                        required: true,
                        helpText: "Integer ranking within the entity; lower is senior.",
                        error: errors.priority
                    )
                    TextArea(
                        name: "description",
                        label: "Description",
                        value: form.description,
                        rows: 3,
                        error: errors.description
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(mode.submitLabel, variant: .primary)
                        LinkButton("Cancel", href: "/admin/share-classes")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        ConfirmDeleteForm(
                            action: "/admin/share-classes/\(id)",
                            label: "Delete share class"
                        )
                    }
                }
            }
        }
    }
}

extension ShareClassFormPage.Mode {
    var pageTitle: String {
        switch self {
        case .new: "New share class"
        case .edit: "Edit share class"
        }
    }
    var formAction: String {
        switch self {
        case .new: "/admin/share-classes"
        case .edit(let id): "/admin/share-classes/\(id)"
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
        case .new: "Create share class"
        case .edit: "Save changes"
        }
    }
}

struct ShareClassFormValues: Sendable {
    let name: String
    let entityId: String
    let priority: String
    let description: String

    init(
        name: String = "",
        entityId: String = "",
        priority: String = "",
        description: String = ""
    ) {
        self.name = name
        self.entityId = entityId
        self.priority = priority
        self.description = description
    }

    init(shareClass: ShareClass) {
        self.name = shareClass.name
        self.entityId = shareClass.$entity.id.uuidString
        self.priority = String(shareClass.priority)
        self.description = shareClass.description ?? ""
    }
}

struct ShareClassFormErrors: Sendable {
    let name: String?
    let entityId: String?
    let priority: String?
    let description: String?
    let summary: [String]

    init(
        name: String? = nil,
        entityId: String? = nil,
        priority: String? = nil,
        description: String? = nil,
        summary: [String] = []
    ) {
        self.name = name
        self.entityId = entityId
        self.priority = priority
        self.description = description
        self.summary = summary
    }

    static let none = ShareClassFormErrors()
}

/// Shared new/edit form for a share issuance.
struct ShareIssuanceFormPage: HTML {
    enum Mode: Sendable {
        case new
        case edit(id: String)
    }

    let brand: any Brand
    let mode: Mode
    let form: ShareIssuanceFormValues
    let errors: ShareIssuanceFormErrors
    let entities: [Entity]
    let people: [Person]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: mode.pageTitle,
            activeSection: .shareIssuances,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: mode.formAction, method: mode.formMethod) {
                    SelectField(
                        name: "entityId",
                        label: "Issuing entity",
                        options: entities.map {
                            SelectOption(value: $0.id?.uuidString ?? "", label: $0.name)
                        },
                        selected: form.entityId,
                        required: true,
                        includeBlank: true,
                        blankLabel: "Pick an entity\u{2026}",
                        error: errors.entityId
                    )
                    SelectField(
                        ShareholderType.self,
                        name: "shareholderType",
                        label: "Shareholder type",
                        selected: form.shareholderTypeEnum ?? .person,
                        required: true,
                        error: errors.shareholderType
                    )
                    SelectField(
                        name: "personShareholderId",
                        label: "Person shareholder",
                        options: people.map {
                            SelectOption(value: $0.id?.uuidString ?? "", label: $0.name)
                        },
                        selected: form.personShareholderId,
                        includeBlank: true,
                        blankLabel: "(only used when shareholder type is person)",
                        helpText: "Required when the shareholder type is person.",
                        error: errors.personShareholderId
                    )
                    SelectField(
                        name: "entityShareholderId",
                        label: "Entity shareholder",
                        options: entities.map {
                            SelectOption(value: $0.id?.uuidString ?? "", label: $0.name)
                        },
                        selected: form.entityShareholderId,
                        includeBlank: true,
                        blankLabel: "(only used when shareholder type is entity)",
                        helpText: "Required when the shareholder type is entity.",
                        error: errors.entityShareholderId
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(mode.submitLabel, variant: .primary)
                        LinkButton("Cancel", href: "/admin/share-issuances")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        ConfirmDeleteForm(
                            action: "/admin/share-issuances/\(id)",
                            label: "Delete issuance"
                        )
                    }
                }
            }
        }
    }
}

extension ShareIssuanceFormPage.Mode {
    var pageTitle: String {
        switch self {
        case .new: "New issuance"
        case .edit: "Edit issuance"
        }
    }
    var formAction: String {
        switch self {
        case .new: "/admin/share-issuances"
        case .edit(let id): "/admin/share-issuances/\(id)"
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
        case .new: "Record issuance"
        case .edit: "Save changes"
        }
    }
}

struct ShareIssuanceFormValues: Sendable {
    let entityId: String
    let shareholderType: String
    let personShareholderId: String
    let entityShareholderId: String

    init(
        entityId: String = "",
        shareholderType: String = "person",
        personShareholderId: String = "",
        entityShareholderId: String = ""
    ) {
        self.entityId = entityId
        self.shareholderType = shareholderType
        self.personShareholderId = personShareholderId
        self.entityShareholderId = entityShareholderId
    }

    init(issuance: ShareIssuance) {
        self.entityId = issuance.$entity.id.uuidString
        self.shareholderType = issuance.shareholderType.rawValue
        switch issuance.shareholderType {
        case .person:
            self.personShareholderId = issuance.shareholderId.uuidString
            self.entityShareholderId = ""
        case .entity:
            self.personShareholderId = ""
            self.entityShareholderId = issuance.shareholderId.uuidString
        }
    }

    var shareholderTypeEnum: ShareholderType? { ShareholderType(rawValue: shareholderType) }
}

struct ShareIssuanceFormErrors: Sendable {
    let entityId: String?
    let shareholderType: String?
    let personShareholderId: String?
    let entityShareholderId: String?
    let summary: [String]

    init(
        entityId: String? = nil,
        shareholderType: String? = nil,
        personShareholderId: String? = nil,
        entityShareholderId: String? = nil,
        summary: [String] = []
    ) {
        self.entityId = entityId
        self.shareholderType = shareholderType
        self.personShareholderId = personShareholderId
        self.entityShareholderId = entityShareholderId
        self.summary = summary
    }

    static let none = ShareIssuanceFormErrors()
}
