import Elementary
import NavigatorWeb

/// `/admin` landing page.
///
/// Lists every resource the admin portal manages so a new operator can
/// see at a glance what is here without having to know the URL surface.
/// Each tile renders the count of rows in the matching table — handed in
/// from the route layer so the page itself stays a pure view.
struct AdminDashboard: HTML {
    let brand: any Brand
    let tiles: [AdminDashboardTile]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Dashboard",
            activeSection: .dashboard,
            brand: brand
        ) {
            div(.class("grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4")) {
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
        }
    }
}

/// One card on the dashboard. `count == nil` renders a placeholder dash
/// so future resources can be slotted in without faking a zero.
struct AdminDashboardTile: Sendable {
    let section: AdminSection
    let count: Int?
}
