import Elementary
import NavigatorDAL
import NavigatorWeb

struct EntityTypesIndexPage: HTML {
    let brand: any Brand
    let entityTypes: [EntityType]
    let flash: String?
    let sort: SortSpec
    let filter: String

    static let sortableKeys: Set<String> = ["name", "jurisdiction"]
    static let defaultSort: SortSpec = .single("name", .ascending)

    static func sorted(_ rows: [EntityType], by spec: SortSpec) -> [EntityType] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return rows.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "name":
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case "jurisdiction":
                return a.jurisdiction.name.localizedCaseInsensitiveCompare(b.jurisdiction.name)
                    == .orderedAscending
            default: return false
            }
        }
    }

    static func filtered(_ rows: [EntityType], by query: String) -> [EntityType] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return rows }
        return rows.filter { $0.name.lowercased().contains(trimmed) }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Entity types",
            activeSection: .entityTypes,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(entityTypes.count) type\(entityTypes.count == 1 ? "" : "s")"
                }
                LinkButton(
                    "New entity type",
                    href: "/admin/entity-types/new",
                    variant: .primary
                )
            }
            AdminFlashBanner(message: flash)
            AdminFilterBar(
                action: "/admin/entity-types",
                value: filter,
                placeholder: "Name\u{2026}"
            )
            if entityTypes.isEmpty {
                AdminEmptyState(
                    message: filter.isEmpty
                        ? "No entity types yet. "
                        : "No types matched \u{201C}\(filter)\u{201D}. ",
                    ctaHref: "/admin/entity-types/new",
                    ctaLabel: "Add one."
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminSortableTH(
                                    "Name",
                                    key: "name",
                                    sort: sort,
                                    basePath: "/admin/entity-types",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "Jurisdiction",
                                    key: "jurisdiction",
                                    sort: sort,
                                    basePath: "/admin/entity-types",
                                    queryItems: queryItems
                                )
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for type in entityTypes {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/entity-types/\(type.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { type.name }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        type.jurisdiction.name
                                    }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/entity-types/\(type.id?.uuidString ?? "")/edit"),
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

struct EntityTypeFormPage: HTML {
    enum Mode: Sendable {
        case new
        case edit(id: String)
    }

    let brand: any Brand
    let mode: Mode
    let form: EntityTypeFormValues
    let errors: EntityTypeFormErrors
    let jurisdictions: [Jurisdiction]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: mode.pageTitle,
            activeSection: .entityTypes,
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
                        helpText: "e.g. LLC, C Corp, Nonprofit Corporation.",
                        error: errors.name
                    )
                    SelectField(
                        name: "jurisdictionId",
                        label: "Jurisdiction",
                        options: jurisdictions.map {
                            SelectOption(
                                value: $0.id?.uuidString ?? "",
                                label: "\($0.name) (\($0.code))"
                            )
                        },
                        selected: form.jurisdictionId,
                        required: true,
                        includeBlank: true,
                        blankLabel: "Pick a jurisdiction\u{2026}",
                        error: errors.jurisdictionId
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(mode.submitLabel, variant: .primary)
                        LinkButton("Cancel", href: "/admin/entity-types")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        p(.class("text-sm text-gray-600 mb-2")) { "Destructive actions" }
                        ConfirmDeleteForm(
                            action: "/admin/entity-types/\(id)",
                            label: "Delete entity type"
                        )
                    }
                }
            }
        }
    }
}

extension EntityTypeFormPage.Mode {
    var pageTitle: String {
        switch self {
        case .new: "New entity type"
        case .edit: "Edit entity type"
        }
    }

    var formAction: String {
        switch self {
        case .new: "/admin/entity-types"
        case .edit(let id): "/admin/entity-types/\(id)"
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
        case .new: "Create entity type"
        case .edit: "Save changes"
        }
    }
}

struct EntityTypeShowPage: HTML {
    let brand: any Brand
    let entityType: EntityType
    let entities: [Entity]

    private var typeID: String { entityType.id?.uuidString ?? "" }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: entityType.name,
            activeSection: .entityTypes,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(
                    .href("/admin/entity-types"),
                    .class("text-sm text-gray-600 hover:underline")
                ) { "\u{2190} Back to entity types" }
                LinkButton(
                    "Edit",
                    href: "/admin/entity-types/\(typeID)/edit",
                    variant: .primary
                )
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Name" }
                    dd(.class("text-gray-900")) { entityType.name }
                    dt(.class("text-gray-500")) { "Jurisdiction" }
                    dd(.class("text-gray-900")) { entityType.jurisdiction.name }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Entities" }
                if entities.isEmpty {
                    p(.class("text-sm text-gray-500")) {
                        "No entities of this type."
                    }
                } else {
                    ul(.class("space-y-1 text-sm")) {
                        for e in entities {
                            li {
                                a(
                                    .href("/admin/entities/\(e.id?.uuidString ?? "")"),
                                    .class("text-indigo-700 hover:underline")
                                ) { e.name }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct EntityTypeFormValues: Sendable {
    let name: String
    let jurisdictionId: String

    init(name: String = "", jurisdictionId: String = "") {
        self.name = name
        self.jurisdictionId = jurisdictionId
    }

    init(entityType: EntityType) {
        self.name = entityType.name
        self.jurisdictionId = entityType.$jurisdiction.id.uuidString
    }
}

struct EntityTypeFormErrors: Sendable {
    let name: String?
    let jurisdictionId: String?
    let summary: [String]

    init(name: String? = nil, jurisdictionId: String? = nil, summary: [String] = []) {
        self.name = name
        self.jurisdictionId = jurisdictionId
        self.summary = summary
    }

    static let none = EntityTypeFormErrors()
}
