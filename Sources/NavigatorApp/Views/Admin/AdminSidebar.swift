import Elementary

/// Left-rail navigation shared by every admin page.
///
/// The sidebar groups sections by ``AdminSidebarGroup`` so the 23-section
/// list stays scannable. The active section carries a
/// `data-active="true"` attribute and a highlighted background — the
/// attribute is what the route tests assert against so the visual class
/// names can move without breaking the suite.
struct AdminSidebar: HTML {
    let active: AdminSection

    var body: some HTML {
        aside(.class("w-60 shrink-0 bg-gray-900 text-gray-100 min-h-screen py-6 px-4")) {
            a(.href("/admin"), .class("block mb-8 px-2")) {
                p(.class("text-xs uppercase tracking-wide text-gray-400")) { "Admin" }
                p(.class("text-lg font-semibold text-white")) { "Navigator" }
            }
            nav(.class("space-y-6"), .custom(name: "aria-label", value: "Admin")) {
                for group in AdminSidebarGroup.allCases {
                    let sections = AdminSection.allCases.filter { $0.group == group }
                    if !sections.isEmpty {
                        div {
                            p(
                                .class(
                                    "text-xs uppercase tracking-wide text-gray-500 mb-2 px-2"
                                )
                            ) { group.label }
                            ul(.class("space-y-1")) {
                                for section in sections {
                                    li {
                                        AdminSidebarLink(section: section, active: active)
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

/// A single sidebar nav link. Pulled out so the active vs inactive class
/// branching reads cleanly and the `data-active` attribute is the single
/// thing tests inspect.
///
/// The inbox row carries a `#inbox-badge` HTMX slot that polls
/// `/admin/api/sidebar-badges/inbox` on load and every 30 seconds, so an
/// operator on any admin page sees the unread count refresh without a
/// full navigation. The slot starts empty — the route returns the badge
/// markup when unread > 0 and a blank span otherwise.
private struct AdminSidebarLink: HTML {
    let section: AdminSection
    let active: AdminSection

    var body: some HTML {
        let isActive = section == active
        a(
            .href(section.href),
            .class(linkClasses(isActive: isActive)),
            .custom(name: "data-section", value: section.rawValue),
            .custom(name: "data-active", value: isActive ? "true" : "false")
        ) {
            span(.class("inline-flex items-center justify-between w-full")) {
                span { section.label }
                if section == .inbox {
                    span(
                        .id("inbox-badge"),
                        .custom(name: "hx-get", value: "/admin/api/sidebar-badges/inbox"),
                        .custom(name: "hx-trigger", value: "load, every 30s"),
                        .custom(name: "hx-swap", value: "innerHTML")
                    ) {}
                }
            }
        }
    }

    private func linkClasses(isActive: Bool) -> String {
        let base = "block px-2 py-1.5 rounded text-sm"
        return isActive
            ? "\(base) bg-indigo-600 text-white"
            : "\(base) text-gray-300 hover:bg-gray-800 hover:text-white"
    }
}
