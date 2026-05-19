import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/people` — sortable, filterable list of every person.
struct PeopleIndexPage: HTML {
    let brand: any Brand
    let people: [Person]
    let flash: String?
    let sort: SortSpec
    let filter: String

    static let sortableKeys: Set<String> = ["name", "email"]
    static let defaultSort: SortSpec = .single("name", .ascending)

    static func sorted(_ people: [Person], by spec: SortSpec) -> [Person] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return people.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "name":
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case "email":
                return a.email.localizedCaseInsensitiveCompare(b.email) == .orderedAscending
            default:
                return false
            }
        }
    }

    static func filtered(_ people: [Person], by query: String) -> [Person] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return people }
        return people.filter {
            $0.name.lowercased().contains(trimmed)
                || $0.email.lowercased().contains(trimmed)
        }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "People",
            activeSection: .people,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(people.count) \(people.count == 1 ? "person" : "people")"
                }
                LinkButton(
                    "New person",
                    href: "/admin/people/new",
                    variant: .primary,
                    dataShortcut: "new"
                )
            }
            AdminFlashBanner(message: flash)
            AdminFilterBar(
                action: "/admin/people",
                value: filter,
                placeholder: "Name or email\u{2026}"
            )
            if people.isEmpty {
                AdminEmptyState(
                    message: filter.isEmpty
                        ? "No people yet. "
                        : "No people matched \u{201C}\(filter)\u{201D}. ",
                    ctaHref: "/admin/people/new",
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
                                    basePath: "/admin/people",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "Email",
                                    key: "email",
                                    sort: sort,
                                    basePath: "/admin/people",
                                    queryItems: queryItems
                                )
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for person in people {
                                tr(
                                    .custom(
                                        name: "data-person-id",
                                        value: person.id?.uuidString ?? ""
                                    ),
                                    .custom(
                                        name: "data-row-href",
                                        value: "/admin/people/\(person.id?.uuidString ?? "")"
                                    )
                                ) {
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(
                                            .href("/admin/people/\(person.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { person.name }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) { person.email }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href(
                                                "/admin/people/\(person.id?.uuidString ?? "")/edit"
                                            ),
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
