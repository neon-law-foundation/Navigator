import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// `/admin` shell coverage: the sidebar, the dashboard, and the active
/// section highlight. Routes for individual resources sit under their
/// own resource tests; this suite only exercises the chrome.
@Suite("Admin shell", .serialized)
struct AdminShellTests {

    @Test("GET /admin returns 200 with the Dashboard title")
    func dashboardRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(">Dashboard<"))
                }
            )
        }
    }

    @Test("dashboard renders a tile for every admin section")
    func dashboardListsEverySection() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    // Each section's `rawValue` shows up as a data-tile
                    // attribute; asserting on rawValue keeps the test
                    // stable when the human label is reworded.
                    #expect(body.contains(#"data-tile="projects""#))
                    #expect(body.contains(#"data-tile="people""#))
                    #expect(body.contains(#"data-tile="entities""#))
                    #expect(body.contains(#"data-tile="messages""#))
                    #expect(body.contains(#"data-tile="retainers""#))
                    #expect(body.contains(#"data-tile="invoices""#))
                }
            )
        }
    }

    @Test("sidebar marks the active section via data-active=\"true\"")
    func sidebarActiveAttribute() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(
                        body.contains(#"data-section="dashboard" data-active="true""#)
                    )
                    #expect(
                        body.contains(#"data-section="projects" data-active="false""#)
                    )
                }
            )
        }
    }

    @Test("sidebar lists every section as a link to its href")
    func sidebarListsEverySectionLink() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"href="/admin/projects""#))
                    #expect(body.contains(#"href="/admin/people""#))
                    #expect(body.contains(#"href="/admin/entities""#))
                    #expect(body.contains(#"href="/admin/notations""#))
                    #expect(body.contains(#"href="/admin/mailroom""#))
                }
            )
        }
    }

    @Test("dashboard title is suffixed with the brand name")
    func dashboardTitleHasBrand() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("<title>Dashboard - Neon Law Foundation Admin</title>"))
                }
            )
        }
    }

    @Test("dashboard is not indexed by search engines")
    func dashboardCarriesNoindex() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"<meta name="robots" content="noindex, nofollow">"#))
                }
            )
        }
    }
}
