import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/contacts` — unified People + Entities list.
///
/// Read-only landing page. Each row is a thin shim around either a
/// `Person` or an `Entity`, with a deep-link to the resource's own
/// detail page. Useful when an operator knows a name but doesn't
/// remember whether that name is filed as a person or a company.
struct AdminContactsPage: HTML {
    let brand: any Brand
    let contacts: [AdminContactRow]
    let filter: String

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Contacts",
            activeSection: .contacts,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(contacts.count) result\(contacts.count == 1 ? "" : "s")"
                }
                div(.class("flex items-center gap-2")) {
                    LinkButton("New person", href: "/admin/people/new")
                    LinkButton(
                        "New entity",
                        href: "/admin/entities/new",
                        variant: .primary
                    )
                }
            }
            form(.action("/admin/contacts"), .method(.get), .class("mb-4")) {
                TextField(
                    name: "q",
                    label: "Search",
                    value: filter.isEmpty ? nil : filter,
                    placeholder: "Filter by name\u{2026}"
                )
                SubmitButton("Search")
            }
            if contacts.isEmpty {
                div(
                    .class(
                        "rounded-lg border border-dashed border-gray-300 p-12 text-center bg-white"
                    )
                ) {
                    p(.class("text-gray-600")) {
                        filter.isEmpty
                            ? "No contacts yet."
                            : "No contacts matched \u{201C}\(filter)\u{201D}."
                    }
                }
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Kind")
                                AdminTableHeader("Name")
                                AdminTableHeader("Detail")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for row in contacts {
                                tr(.custom(name: "data-kind", value: row.kind)) {
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        row.kind == "person" ? "Person" : "Entity"
                                    }
                                    td(.class("px-4 py-3 text-sm")) {
                                        a(.href(row.href), .class("text-indigo-700 hover:underline")) {
                                            row.name
                                        }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) { row.detail }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One row in ``AdminContactsPage``. Built from either a `Person` or an
/// `Entity` so the page can render them in a single table.
struct AdminContactRow: Sendable {
    let kind: String
    let name: String
    let detail: String
    let href: String

    static func person(_ person: Person) -> AdminContactRow {
        AdminContactRow(
            kind: "person",
            name: person.name,
            detail: person.email,
            href: "/admin/people/\(person.id?.uuidString ?? "")"
        )
    }

    static func entity(_ entity: Entity) -> AdminContactRow {
        AdminContactRow(
            kind: "entity",
            name: entity.name,
            detail: entity.legalEntityType.name,
            href: "/admin/entities/\(entity.id?.uuidString ?? "")"
        )
    }
}
