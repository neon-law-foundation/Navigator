import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Global search", .serialized)
struct AdminSearchTests {

    @Test("GET /admin/search renders the full-page shell with empty q")
    func emptyQueryRendersShell() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/search",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains("<title>Search"))
                    #expect(body.contains(#"name="q""#))
                    #expect(body.contains("Type a search above"))
                }
            )
        }
    }

    @Test("?q= finds a Project by codename")
    func findsProject() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let codename = "search-proj-\(UUID().uuidString.prefix(6))"
            let p = Project()
            p.codename = codename
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/search?q=\(codename)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-search-section="projects""#))
                    #expect(body.contains(codename))
                    // Show-all link preserves the query.
                    #expect(body.contains(#"href="/admin/projects?q=\#(codename)""#))
                }
            )
        }
    }

    @Test("?q= finds a Person by name or email")
    func findsPerson() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let unique = "needle-\(UUID().uuidString.prefix(6))"
            let person = Person()
            person.name = "Search Subject \(unique)"
            person.email = "\(unique)@example.com"
            try await person.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/search?q=\(unique)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-search-section="people""#))
                    #expect(body.contains(person.name))
                }
            )
        }
    }

    @Test("?q= finds an Entity by name")
    func findsEntity() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let entityType = try await EntityType.query(on: db).first()
            try #require(entityType != nil)
            let unique = "entneedle-\(UUID().uuidString.prefix(6))"
            let e = Entity()
            e.name = "Findable Co \(unique)"
            e.$legalEntityType.id = entityType!.id!
            try await e.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/search?q=\(unique)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-search-section="entities""#))
                    #expect(body.contains(e.name))
                }
            )
        }
    }

    @Test("?q= finds an inbound message by subject")
    func findsInbox() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let unique = "inbsearch-\(UUID().uuidString.prefix(6))"
            let blob = Blob()
            blob.objectStorageUrl = "s3://test/raw.eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let m = EmailMessage()
            m.messageId = "<\(UUID().uuidString)@example.com>"
            m.threadId = m.messageId
            m.fromAddress = "anon@example.com"
            m.toAddress = "support@neonlaw.org"
            m.subject = "Subject with \(unique)"
            m.$rawBlob.id = blob.id!
            m.spamVerdict = "PASS"
            m.virusVerdict = "PASS"
            m.dkimVerdict = "PASS"
            m.dmarcVerdict = "PASS"
            m.receivedAt = Date()
            try await m.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/search?q=\(unique)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-search-section="inbox""#))
                    #expect(body.contains(unique))
                }
            )
        }
    }

    @Test("HX-Request returns just the results fragment, not the full page")
    func hxRequestReturnsFragment() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let codename = "hx-\(UUID().uuidString.prefix(6))"
            let p = Project()
            p.codename = codename
            try await p.save(on: db)
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: "HX-Request", value: "true")
            try await app.testing().test(
                .GET,
                "/admin/search?q=\(codename)",
                headers: headers,
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(res.status == .ok)
                    // Fragment-only: no <html>, <body>, sidebar chrome.
                    #expect(!body.contains("<html"))
                    #expect(!body.contains("data-section=\"dashboard\""))
                    // But it still contains the projects section.
                    #expect(body.contains(#"data-search-section="projects""#))
                    #expect(body.contains(codename))
                }
            )
        }
    }

    @Test("?q= with no matches shows empty-state per section")
    func emptyResults() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/search?q=zzz-no-match-\(UUID().uuidString)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("No matches"))
                }
            )
        }
    }

    @Test("AdminPageLayout includes HTMX so the search input can live-update")
    func htmxLoaded() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/search",
                afterResponse: { res async in
                    let body = res.body.string
                    // HTMX script tag is in the head; the search input
                    // pulls it from a CDN like Tailwind does.
                    #expect(body.contains("htmx.org") || body.contains("htmx.min.js"))
                    // The input is wired to HTMX so typing live-updates
                    // results without a full reload.
                    #expect(body.contains(#"hx-get="/admin/search""#))
                    #expect(body.contains(##"hx-target="#search-results""##))
                }
            )
        }
    }

    @Test("Search link appears in the admin sidebar")
    func sidebarHasSearchEntry() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-section="search""#))
                    #expect(body.contains(#"href="/admin/search""#))
                }
            )
        }
    }
}
