import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Help page", .serialized)
struct AdminHelpPageTests {

    @Test("GET /admin/help renders the chromed help page")
    func helpRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/help",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(">Help<"))
                    #expect(body.contains(#"data-section="dashboard""#))
                }
            )
        }
    }

    @Test("help page documents every keyboard shortcut")
    func keyboardShortcuts() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/help",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-section="keyboard-shortcuts""#))
                    #expect(body.contains("Move the row highlight down"))
                    #expect(body.contains("Move the row highlight up"))
                    #expect(body.contains("Focus the filter search box"))
                    #expect(body.contains("Shift + N"))
                }
            )
        }
    }

    @Test("help page documents JSON:API sort syntax")
    func sortSyntax() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/help",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-section="sort-filter""#))
                    #expect(body.contains("?sort=name"))
                    #expect(body.contains("?sort=-name"))
                    #expect(body.contains("?sort=-receivedAt,subject"))
                    #expect(body.contains("?q=acme"))
                }
            )
        }
    }

    @Test("help page lists the export URLs")
    func exports() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/help",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-section="exports""#))
                    #expect(body.contains("/admin/contacts.vcf"))
                    #expect(body.contains("/admin/&lt;resource&gt;.csv"))
                    #expect(body.contains("/admin/projects/&lt;id&gt;/print"))
                }
            )
        }
    }
}
