import Elementary
import NavigatorWeb

/// `/admin/help` — a static reference page documenting the conventions
/// every admin route shares: keyboard shortcuts, JSON:API sort and
/// filter syntax, HTMX fragment behavior, and admin URL surfaces an
/// operator can reach by typing.
///
/// The page reuses ``AdminPageLayout`` so it stays one navigation away
/// from any resource the operator is currently on. No DB access — the
/// content is hard-coded reference material, so the route is cheap and
/// safe to hit from a 503/error state.
struct AdminHelpPage: HTML {
    let brand: any Brand

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Help",
            activeSection: .dashboard,
            brand: brand
        ) {
            section(
                .class("bg-white rounded-lg border border-gray-200 p-6 mb-6"),
                .custom(name: "data-section", value: "keyboard-shortcuts")
            ) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) {
                    "Keyboard shortcuts"
                }
                p(.class("text-sm text-gray-600 mb-4")) {
                    "Shortcuts are wired through Alpine.js on every admin page. "
                        + "They fire when the focus is anywhere outside a form input."
                }
                ul(.class("space-y-2 text-sm")) {
                    shortcut(key: "j", description: "Move the row highlight down.")
                    shortcut(key: "k", description: "Move the row highlight up.")
                    shortcut(
                        key: "Enter",
                        description: "Open the highlighted row's show page."
                    )
                    shortcut(
                        key: "/",
                        description:
                            "Focus the filter search box (whichever resource you're on)."
                    )
                    shortcut(
                        key: "Shift + N",
                        description: "Open the \u{201C}New \u{2026}\u{201D} page for this resource."
                    )
                }
            }
            section(
                .class("bg-white rounded-lg border border-gray-200 p-6 mb-6"),
                .custom(name: "data-section", value: "sort-filter")
            ) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) {
                    "Sort & filter via the URL"
                }
                p(.class("text-sm text-gray-600 mb-4")) {
                    "Every admin index page accepts JSON:API 1.1 sort and filter "
                        + "query parameters. Unknown sort fields return 400 so a "
                        + "typo is easy to catch."
                }
                dl(.class("grid grid-cols-3 gap-y-2 text-sm")) {
                    dt(.class("col-span-1 font-mono text-gray-500")) { "?sort=name" }
                    dd(.class("col-span-2 text-gray-700")) {
                        "Ascending by name."
                    }
                    dt(.class("col-span-1 font-mono text-gray-500")) { "?sort=-name" }
                    dd(.class("col-span-2 text-gray-700")) {
                        "Descending by name (leading minus)."
                    }
                    dt(.class("col-span-1 font-mono text-gray-500")) {
                        "?sort=-receivedAt,subject"
                    }
                    dd(.class("col-span-2 text-gray-700")) {
                        "Multi-field. Primary first."
                    }
                    dt(.class("col-span-1 font-mono text-gray-500")) { "?q=acme" }
                    dd(.class("col-span-2 text-gray-700")) {
                        "Substring filter on whichever fields the page supports."
                    }
                    dt(.class("col-span-1 font-mono text-gray-500")) {
                        "?page=2&perPage=25"
                    }
                    dd(.class("col-span-2 text-gray-700")) {
                        "Pagination. perPage caps at the page's stated limit."
                    }
                }
            }
            section(
                .class("bg-white rounded-lg border border-gray-200 p-6 mb-6"),
                .custom(name: "data-section", value: "exports")
            ) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Exports" }
                ul(.class("space-y-2 text-sm")) {
                    bullet {
                        a(
                            .href("/admin/contacts.vcf"),
                            .class("font-mono text-indigo-700 hover:underline")
                        ) { "/admin/contacts.vcf" }
                        " — RFC 6350 vCard 4.0 for every person."
                    }
                    bullet {
                        span(.class("font-mono text-gray-700")) {
                            "/admin/<resource>.csv"
                        }
                        " — RFC 4180 CSV for projects, people, entities, notations, and the inbox."
                    }
                    bullet {
                        span(.class("font-mono text-gray-700")) {
                            "/admin/projects/<id>/print"
                        }
                        " — chrome-free project summary suitable for the browser's print dialog."
                    }
                }
            }
            section(
                .class("bg-white rounded-lg border border-gray-200 p-6"),
                .custom(name: "data-section", value: "htmx")
            ) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) {
                    "HTMX fragment responses"
                }
                p(.class("text-sm text-gray-600 mb-2")) {
                    "Routes that drive HTMX swaps look at the "
                        + "\u{201C}HX-Request: true\u{201D} header. When present, the "
                        + "response is a fragment intended for in-place insertion; "
                        + "the same URL returns a full page on a normal navigation."
                }
                p(.class("text-sm text-gray-600")) {
                    "The sidebar's unread-mail badge polls "
                        + "/admin/api/sidebar-badges/inbox every 30 seconds, so an "
                        + "operator on any page sees the count refresh without a navigation."
                }
            }
        }
    }

    private func shortcut(key: String, description: String) -> some HTML {
        li(.class("flex items-start gap-3")) {
            kbd(
                .class(
                    "inline-flex items-center px-2 py-0.5 rounded text-xs font-mono bg-gray-100 text-gray-800 border border-gray-300 shrink-0"
                )
            ) { key }
            span(.class("text-gray-700")) { description }
        }
    }

    @HTMLBuilder
    private func bullet<C: HTML>(@HTMLBuilder _ content: () -> C) -> some HTML {
        li(.class("flex items-start gap-2 text-gray-700")) {
            span(.class("text-gray-400")) { "\u{2022}" }
            span { content() }
        }
    }
}
