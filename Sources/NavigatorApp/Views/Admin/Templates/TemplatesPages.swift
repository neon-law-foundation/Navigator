import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/templates` — read-only list of every template version.
///
/// Templates are sourced from git repositories and versioned by commit SHA;
/// admin operators cannot create one through the UI. The index renders a
/// row per version with a deep link to the version-specific show page.
struct TemplatesIndexPage: HTML {
    let brand: any Brand
    let templates: [Template]
    let sort: SortSpec
    let filter: String

    static let sortableKeys: Set<String> = ["title", "code", "version"]
    static let defaultSort: SortSpec = .single("title", .ascending)

    static func sorted(_ rows: [Template], by spec: SortSpec) -> [Template] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return rows.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "title":
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case "code":
                return (a.code ?? "").localizedCaseInsensitiveCompare(b.code ?? "")
                    == .orderedAscending
            case "version":
                return a.version.localizedCaseInsensitiveCompare(b.version) == .orderedAscending
            default: return false
            }
        }
    }

    static func filtered(_ rows: [Template], by query: String) -> [Template] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return rows }
        return rows.filter {
            $0.title.lowercased().contains(trimmed)
                || ($0.code?.lowercased().contains(trimmed) ?? false)
        }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Templates",
            activeSection: .templates,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(templates.count) version\(templates.count == 1 ? "" : "s")"
                }
                p(.class("text-xs text-gray-500")) {
                    "Templates are sourced from git; create a new version by committing to the source repository."
                }
            }
            AdminFilterBar(
                action: "/admin/templates",
                value: filter,
                placeholder: "Title or code\u{2026}"
            )
            if templates.isEmpty {
                div(
                    .class(
                        "rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white"
                    )
                ) {
                    p(.class("text-gray-600")) {
                        filter.isEmpty
                            ? "No templates yet."
                            : "No templates matched \u{201C}\(filter)\u{201D}."
                    }
                }
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminSortableTH(
                                    "Title",
                                    key: "title",
                                    sort: sort,
                                    basePath: "/admin/templates",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "Code",
                                    key: "code",
                                    sort: sort,
                                    basePath: "/admin/templates",
                                    queryItems: queryItems
                                )
                                AdminTableHeader("Respondent")
                                AdminSortableTH(
                                    "Version",
                                    key: "version",
                                    sort: sort,
                                    basePath: "/admin/templates",
                                    queryItems: queryItems
                                )
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for t in templates {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/templates/\(t.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { t.title }
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-700")) {
                                        t.code ?? "\u{2014}"
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        t.respondentType.rawValue
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                        String(t.version.prefix(8))
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

/// `/admin/templates/:id` — read-only detail.
struct TemplateShowPage: HTML {
    let brand: any Brand
    let template: Template
    let activity: [AdminActivityEvent]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: template.title,
            activeSection: .templates,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/templates"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to templates"
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Details" }
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Title" }
                    dd(.class("text-gray-900")) { template.title }
                    dt(.class("text-gray-500")) { "Code" }
                    dd(.class("font-mono text-gray-900")) { template.code ?? "\u{2014}" }
                    dt(.class("text-gray-500")) { "Description" }
                    dd(.class("text-gray-900")) { template.description }
                    dt(.class("text-gray-500")) { "Respondent type" }
                    dd(.class("text-gray-900")) { template.respondentType.rawValue }
                    dt(.class("text-gray-500")) { "Version" }
                    dd(.class("font-mono text-gray-900 break-all")) { template.version }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Markdown content" }
                pre(
                    .class("text-xs bg-gray-50 p-4 rounded overflow-x-auto text-gray-800")
                ) { template.markdownContent }
            }
            AdminActivitySection(
                events: activity,
                emptyMessage: "No activity recorded for this template version."
            )
        }
    }
}
