import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/projects` — sortable, filterable list of every project.
struct ProjectsIndexPage: HTML {
    let brand: any Brand
    let projects: [Project]
    let flash: String?
    let sort: SortSpec
    let filter: String
    let pagination: AdminPagination

    static let sortableKeys: Set<String> = ["codename", "title", "status", "projectType"]
    static let defaultSort: SortSpec = .single("codename", .ascending)

    /// Sorts `projects` by the spec's primary field. The list of allowed
    /// keys mirrors the sortable columns the page renders so the route
    /// handler's validation and the view stay in lockstep.
    static func sorted(_ projects: [Project], by spec: SortSpec) -> [Project] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return projects.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "codename":
                return a.codename.localizedCaseInsensitiveCompare(b.codename) == .orderedAscending
            case "title":
                return (a.title ?? "").localizedCaseInsensitiveCompare(b.title ?? "")
                    == .orderedAscending
            case "status":
                return (a.status?.rawValue ?? "").localizedCaseInsensitiveCompare(
                    b.status?.rawValue ?? ""
                ) == .orderedAscending
            case "projectType":
                return (a.projectType?.rawValue ?? "").localizedCaseInsensitiveCompare(
                    b.projectType?.rawValue ?? ""
                ) == .orderedAscending
            default:
                return false
            }
        }
    }

    /// Case-insensitive substring match on codename and title.
    static func filtered(_ projects: [Project], by query: String) -> [Project] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return projects }
        return projects.filter {
            $0.codename.lowercased().contains(trimmed)
                || ($0.title?.lowercased().contains(trimmed) ?? false)
        }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

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
            AdminFlashBanner(message: flash)
            AdminFilterBar(
                action: "/admin/projects",
                value: filter,
                placeholder: "Codename or title\u{2026}"
            )
            if projects.isEmpty {
                AdminEmptyState(
                    message: filter.isEmpty
                        ? "No projects yet. "
                        : "No projects matched \u{201C}\(filter)\u{201D}. ",
                    ctaHref: "/admin/projects/new",
                    ctaLabel: "Create one."
                )
            } else {
                form(
                    .action("/admin/projects/archive-bulk"),
                    .method(.post)
                ) {
                    div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                        table(.class("min-w-full divide-y divide-gray-200")) {
                            thead(.class("bg-gray-50")) {
                                tr {
                                    AdminTableHeader("")
                                    AdminSortableTH(
                                        "Codename",
                                        key: "codename",
                                        sort: sort,
                                        basePath: "/admin/projects",
                                        queryItems: queryItems
                                    )
                                    AdminSortableTH(
                                        "Title",
                                        key: "title",
                                        sort: sort,
                                        basePath: "/admin/projects",
                                        queryItems: queryItems
                                    )
                                    AdminSortableTH(
                                        "Status",
                                        key: "status",
                                        sort: sort,
                                        basePath: "/admin/projects",
                                        queryItems: queryItems
                                    )
                                    AdminSortableTH(
                                        "Type",
                                        key: "projectType",
                                        sort: sort,
                                        basePath: "/admin/projects",
                                        queryItems: queryItems
                                    )
                                    AdminTableHeader("", alignment: .right)
                                }
                            }
                            tbody(.class("divide-y divide-gray-100")) {
                                for project in projects {
                                    tr(
                                        .custom(
                                            name: "data-project-id",
                                            value: project.id?.uuidString ?? ""
                                        )
                                    ) {
                                        td(.class("px-4 py-3 text-sm w-8")) {
                                            input(
                                                .type(.checkbox),
                                                .name("ids[]"),
                                                .value(project.id?.uuidString ?? "")
                                            )
                                        }
                                        td(.class("px-4 py-3 text-sm")) {
                                            a(
                                                .href(
                                                    "/admin/projects/\(project.id?.uuidString ?? "")"
                                                ),
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
                                                .href(
                                                    "/admin/projects/\(project.id?.uuidString ?? "")/edit"
                                                ),
                                                .class("text-gray-600 hover:text-gray-900")
                                            ) { "Edit" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    div(.class("flex justify-end mt-4")) {
                        SubmitButton("Archive selected", variant: .danger)
                    }
                }
                AdminPaginationFooter(pagination: pagination)
            }
        }
    }
}
