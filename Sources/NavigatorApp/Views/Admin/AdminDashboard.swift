import Elementary
import NavigatorWeb

/// `/admin` landing page.
///
/// Lists every resource the admin portal manages so a new operator can
/// see at a glance what is here without having to know the URL surface.
/// Each tile renders the count of rows in the matching table — handed in
/// from the route layer so the page itself stays a pure view.
///
/// Below the tiles, a "Recent activity" section renders cross-resource
/// events (project / person / entity / notation creations + inbound
/// mail) so the operator has a single answer to "what changed lately?"
/// without walking each resource.
struct AdminDashboard: HTML {
    let brand: any Brand
    let tiles: [AdminDashboardTile]
    let activity: [AdminActivityEvent]
    let since: String

    init(
        brand: any Brand,
        tiles: [AdminDashboardTile],
        activity: [AdminActivityEvent] = [],
        since: String = ""
    ) {
        self.brand = brand
        self.tiles = tiles
        self.activity = activity
        self.since = since
    }

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Dashboard",
            activeSection: .dashboard,
            brand: brand
        ) {
            div(.class("grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-8")) {
                for tile in tiles {
                    a(
                        .href(tile.section.href),
                        .class(
                            "block rounded-lg border border-gray-200 bg-white p-5 hover:shadow"
                        ),
                        .custom(name: "data-tile", value: tile.section.rawValue)
                    ) {
                        p(.class("text-xs uppercase tracking-wide text-gray-500")) {
                            tile.section.group.label
                        }
                        p(.class("text-lg font-semibold text-gray-900 mt-1")) {
                            tile.section.label
                        }
                        if let count = tile.count {
                            p(.class("text-3xl font-bold text-indigo-600 mt-3")) {
                                String(count)
                            }
                            p(.class("text-xs text-gray-500")) { "rows" }
                        } else {
                            p(.class("text-3xl font-bold text-gray-300 mt-3")) { "\u{2014}" }
                            p(.class("text-xs text-gray-400")) { "no counter yet" }
                        }
                    }
                }
            }
            section(
                .class("bg-white rounded-lg border border-gray-200 p-6"),
                .custom(name: "data-section", value: "recent-activity")
            ) {
                div(.class("flex items-center justify-between mb-4")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Recent activity" }
                    form(
                        .action("/admin"),
                        .method(.get),
                        .class("flex items-center gap-2")
                    ) {
                        label(.for("since"), .class("text-xs text-gray-500")) { "Since" }
                        input(
                            .type(.date),
                            .name("since"),
                            .id("since"),
                            .value(since),
                            .class(
                                "rounded border border-gray-300 text-sm px-2 py-1"
                            )
                        )
                        button(
                            .type(.submit),
                            .class(
                                "text-xs text-indigo-700 hover:underline"
                            )
                        ) { "Apply" }
                    }
                }
                if activity.isEmpty {
                    p(.class("text-sm text-gray-500")) {
                        "No activity in the selected window."
                    }
                } else {
                    ol(.class("space-y-3")) {
                        for event in activity {
                            li(
                                .class("flex items-start gap-3"),
                                .custom(name: "data-kind", value: event.kind)
                            ) {
                                span(
                                    .class(
                                        "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium \(event.chipPalette)"
                                    )
                                ) { event.label }
                                div(.class("flex-1")) {
                                    if let href = event.href {
                                        a(
                                            .href(href),
                                            .class(
                                                "text-sm text-indigo-700 hover:underline"
                                            )
                                        ) { event.description }
                                    } else {
                                        p(.class("text-sm text-gray-800")) {
                                            event.description
                                        }
                                    }
                                    p(.class("text-xs font-mono text-gray-500")) {
                                        AdminActivitySection.formatter.string(
                                            from: event.timestamp
                                        )
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

/// One card on the dashboard. `count == nil` renders a placeholder dash
/// so future resources can be slotted in without faking a zero.
struct AdminDashboardTile: Sendable {
    let section: AdminSection
    let count: Int?
}
