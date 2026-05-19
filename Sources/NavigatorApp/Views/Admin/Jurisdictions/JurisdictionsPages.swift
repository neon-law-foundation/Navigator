import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/jurisdictions` — list view.
struct JurisdictionsIndexPage: HTML {
    let brand: any Brand
    let jurisdictions: [Jurisdiction]
    let flash: String?
    let sort: SortSpec
    let filter: String

    static let sortableKeys: Set<String> = ["name", "code", "type"]
    static let defaultSort: SortSpec = .single("name", .ascending)

    static func sorted(_ rows: [Jurisdiction], by spec: SortSpec) -> [Jurisdiction] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return rows.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "name":
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case "code":
                return a.code.localizedCaseInsensitiveCompare(b.code) == .orderedAscending
            case "type":
                return a.jurisdictionType.rawValue.localizedCaseInsensitiveCompare(
                    b.jurisdictionType.rawValue
                ) == .orderedAscending
            default: return false
            }
        }
    }

    static func filtered(_ rows: [Jurisdiction], by query: String) -> [Jurisdiction] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return rows }
        return rows.filter {
            $0.name.lowercased().contains(trimmed)
                || $0.code.lowercased().contains(trimmed)
        }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Jurisdictions",
            activeSection: .jurisdictions,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(jurisdictions.count) jurisdiction\(jurisdictions.count == 1 ? "" : "s")"
                }
                LinkButton(
                    "New jurisdiction",
                    href: "/admin/jurisdictions/new",
                    variant: .primary
                )
            }
            AdminFlashBanner(message: flash)
            AdminFilterBar(
                action: "/admin/jurisdictions",
                value: filter,
                placeholder: "Name or code\u{2026}"
            )
            if jurisdictions.isEmpty {
                AdminEmptyState(
                    message: filter.isEmpty
                        ? "No jurisdictions yet. "
                        : "No jurisdictions matched \u{201C}\(filter)\u{201D}. ",
                    ctaHref: "/admin/jurisdictions/new",
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
                                    basePath: "/admin/jurisdictions",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "Code",
                                    key: "code",
                                    sort: sort,
                                    basePath: "/admin/jurisdictions",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "Type",
                                    key: "type",
                                    sort: sort,
                                    basePath: "/admin/jurisdictions",
                                    queryItems: queryItems
                                )
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for j in jurisdictions {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/jurisdictions/\(j.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { j.name }
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-700")) { j.code }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) { j.jurisdictionType.rawValue }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/jurisdictions/\(j.id?.uuidString ?? "")/edit"),
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

/// Shared new/edit form for a jurisdiction.
struct JurisdictionFormPage: HTML {
    enum Mode: Sendable {
        case new
        case edit(id: String)
    }

    let brand: any Brand
    let mode: Mode
    let form: JurisdictionFormValues
    let errors: JurisdictionFormErrors

    var body: some HTML {
        AdminPageLayout(
            pageTitle: mode.pageTitle,
            activeSection: .jurisdictions,
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
                    TextField(
                        name: "code",
                        label: "Code",
                        value: form.code,
                        required: true,
                        helpText: "Postal-style abbreviation (NV, US-CA, USA, …).",
                        error: errors.code
                    )
                    SelectField(
                        JurisdictionType.self,
                        name: "jurisdictionType",
                        label: "Type",
                        selected: form.typeEnum,
                        required: true,
                        error: errors.jurisdictionType
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(mode.submitLabel, variant: .primary)
                        LinkButton("Cancel", href: "/admin/jurisdictions")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        p(.class("text-sm text-gray-600 mb-2")) { "Destructive actions" }
                        ConfirmDeleteForm(
                            action: "/admin/jurisdictions/\(id)",
                            label: "Delete jurisdiction",
                            confirmMessage: "Delete this jurisdiction?"
                        )
                    }
                }
            }
        }
    }
}

extension JurisdictionFormPage.Mode {
    var pageTitle: String {
        switch self {
        case .new: "New jurisdiction"
        case .edit: "Edit jurisdiction"
        }
    }

    var formAction: String {
        switch self {
        case .new: "/admin/jurisdictions"
        case .edit(let id): "/admin/jurisdictions/\(id)"
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
        case .new: "Create jurisdiction"
        case .edit: "Save changes"
        }
    }
}

/// `/admin/jurisdictions/:id` — detail view. Includes a read-only list of
/// the entity types defined under this jurisdiction.
struct JurisdictionShowPage: HTML {
    let brand: any Brand
    let jurisdiction: Jurisdiction
    let entityTypes: [EntityType]

    private var jurisdictionID: String { jurisdiction.id?.uuidString ?? "" }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: jurisdiction.name,
            activeSection: .jurisdictions,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/jurisdictions"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to jurisdictions"
                }
                LinkButton(
                    "Edit",
                    href: "/admin/jurisdictions/\(jurisdictionID)/edit",
                    variant: .primary
                )
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Name" }
                    dd(.class("text-gray-900")) { jurisdiction.name }
                    dt(.class("text-gray-500")) { "Code" }
                    dd(.class("font-mono text-gray-900")) { jurisdiction.code }
                    dt(.class("text-gray-500")) { "Type" }
                    dd(.class("text-gray-900")) { jurisdiction.jurisdictionType.rawValue }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Entity types" }
                if entityTypes.isEmpty {
                    p(.class("text-sm text-gray-500")) {
                        "No entity types defined under this jurisdiction yet."
                    }
                } else {
                    ul(.class("space-y-1 text-sm")) {
                        for type in entityTypes {
                            li {
                                a(
                                    .href("/admin/entity-types/\(type.id?.uuidString ?? "")"),
                                    .class("text-indigo-700 hover:underline")
                                ) { type.name }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct JurisdictionFormValues: Sendable {
    let name: String
    let code: String
    let jurisdictionType: String

    init(name: String = "", code: String = "", jurisdictionType: String = "") {
        self.name = name
        self.code = code
        self.jurisdictionType = jurisdictionType
    }

    init(jurisdiction: Jurisdiction) {
        self.name = jurisdiction.name
        self.code = jurisdiction.code
        self.jurisdictionType = jurisdiction.jurisdictionType.rawValue
    }

    var typeEnum: JurisdictionType? { JurisdictionType(rawValue: jurisdictionType) }
}

struct JurisdictionFormErrors: Sendable {
    let name: String?
    let code: String?
    let jurisdictionType: String?
    let summary: [String]

    init(
        name: String? = nil,
        code: String? = nil,
        jurisdictionType: String? = nil,
        summary: [String] = []
    ) {
        self.name = name
        self.code = code
        self.jurisdictionType = jurisdictionType
        self.summary = summary
    }

    static let none = JurisdictionFormErrors()
}
