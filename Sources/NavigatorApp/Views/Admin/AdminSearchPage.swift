import Elementary
import NavigatorDAL
import NavigatorWeb

/// `/admin/search` — one place to search across every major resource.
///
/// The input is wired to HTMX so each keystroke (debounced) issues a
/// GET against the same URL and swaps just the results panel. The full
/// page still works without JS — the form submits as a regular GET and
/// the server re-renders the same response shape.
struct AdminSearchPage: HTML {
    let brand: any Brand
    let query: String
    let results: AdminSearchResultBundle

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Search",
            activeSection: .search,
            brand: brand
        ) {
            div(.class("max-w-3xl")) {
                form(
                    .action("/admin/search"),
                    .method(.get),
                    .class("mb-6 flex items-center gap-2")
                ) {
                    input(
                        .type(.search),
                        .name("q"),
                        .value(query),
                        .custom(name: "placeholder", value: "Search\u{2026}"),
                        .class(
                            "block w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-300"
                        ),
                        .custom(name: "hx-get", value: "/admin/search"),
                        .custom(name: "hx-target", value: "#search-results"),
                        .custom(name: "hx-trigger", value: "keyup changed delay:250ms"),
                        .custom(name: "hx-push-url", value: "true"),
                        .custom(name: "autofocus", value: "autofocus")
                    )
                    button(
                        .type(.submit),
                        .class(
                            "inline-flex items-center px-3 py-2 rounded-md text-sm font-medium bg-gray-200 text-gray-800 hover:bg-gray-300"
                        )
                    ) { "Search" }
                }
                div(.id("search-results")) {
                    AdminSearchResults(query: query, results: results)
                }
            }
        }
    }
}

/// Fragment that `AdminSearchPage` renders inline and that the route
/// returns standalone when `HX-Request: true` is on the request.
struct AdminSearchResults: HTML {
    let query: String
    let results: AdminSearchResultBundle

    var body: some HTML {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            p(.class("text-sm text-gray-500")) {
                "Type a search above to find projects, people, entities, or messages."
            }
        } else if results.isEmpty {
            div(
                .class(
                    "rounded-lg border border-dashed border-gray-300 p-6 text-center bg-white"
                )
            ) {
                p(.class("text-sm text-gray-600")) {
                    "No matches for \u{201C}\(query)\u{201D}."
                }
            }
        } else {
            div(.class("space-y-6")) {
                AdminSearchSectionView(
                    sectionKey: "projects",
                    title: "Projects",
                    showAllHref: "/admin/projects?q=\(query)",
                    rows: results.projects.map { p in
                        AdminSearchHit(
                            label: p.codename,
                            secondary: p.title ?? "",
                            href: "/admin/projects/\(p.id?.uuidString ?? "")"
                        )
                    }
                )
                AdminSearchSectionView(
                    sectionKey: "people",
                    title: "People",
                    showAllHref: "/admin/people?q=\(query)",
                    rows: results.people.map { person in
                        AdminSearchHit(
                            label: person.name,
                            secondary: person.email,
                            href: "/admin/people/\(person.id?.uuidString ?? "")"
                        )
                    }
                )
                AdminSearchSectionView(
                    sectionKey: "entities",
                    title: "Entities",
                    showAllHref: "/admin/entities?q=\(query)",
                    rows: results.entities.map { e in
                        AdminSearchHit(
                            label: e.name,
                            secondary: e.legalEntityType.name,
                            href: "/admin/entities/\(e.id?.uuidString ?? "")"
                        )
                    }
                )
                AdminSearchSectionView(
                    sectionKey: "inbox",
                    title: "Inbox",
                    showAllHref: "/admin/inbox?q=\(query)",
                    rows: results.inbound.map { m in
                        AdminSearchHit(
                            label: m.subject,
                            secondary: "From \(m.fromName ?? m.fromAddress)",
                            href: "/admin/inbox/\(m.id?.uuidString ?? "")"
                        )
                    }
                )
                AdminSearchSectionView(
                    sectionKey: "messages",
                    title: "Messages",
                    showAllHref: "/admin/messages?q=\(query)",
                    rows: results.outbound.map { m in
                        AdminSearchHit(
                            label: m.subject,
                            secondary: "To \(m.toAddress)",
                            href: "/admin/messages/\(m.id?.uuidString ?? "")"
                        )
                    }
                )
            }
        }
    }
}

/// One results section in the search page.
struct AdminSearchSectionView: HTML {
    let sectionKey: String
    let title: String
    let showAllHref: String
    let rows: [AdminSearchHit]

    var body: some HTML {
        if !rows.isEmpty {
            section(
                .class("bg-white rounded-lg border border-gray-200 p-4"),
                .custom(name: "data-search-section", value: sectionKey)
            ) {
                div(.class("flex items-center justify-between mb-3")) {
                    h2(.class("text-sm font-semibold uppercase tracking-wide text-gray-700")) {
                        "\(title) (\(rows.count))"
                    }
                    a(.href(showAllHref), .class("text-xs text-indigo-700 hover:underline")) {
                        "Show all in \(title) \u{2192}"
                    }
                }
                ul(.class("space-y-1 text-sm")) {
                    for row in rows {
                        li {
                            a(.href(row.href), .class("text-indigo-700 hover:underline")) {
                                row.label
                            }
                            if !row.secondary.isEmpty {
                                span(.class("text-gray-500")) { " — \(row.secondary)" }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One hit row in a section list.
struct AdminSearchHit: Sendable {
    let label: String
    let secondary: String
    let href: String
}

/// Per-resource buckets of search results.
struct AdminSearchResultBundle: Sendable {
    let projects: [Project]
    let people: [Person]
    let entities: [Entity]
    let inbound: [EmailMessage]
    let outbound: [EmailMessage]

    var isEmpty: Bool {
        projects.isEmpty && people.isEmpty && entities.isEmpty && inbound.isEmpty && outbound.isEmpty
    }
}
