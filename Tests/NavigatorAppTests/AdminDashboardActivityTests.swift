import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

/// Tests for the cross-resource recent-activity feed rendered below the
/// tile grid on `/admin`.
@Suite("Admin: Dashboard recent activity", .serialized)
struct AdminDashboardActivityTests {

    @Test("dashboard renders the recent-activity section")
    func sectionRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    let body = res.body.string
                    #expect(body.contains(#"data-section="recent-activity""#))
                    #expect(body.contains(">Recent activity<"))
                    #expect(body.contains(#"name="since""#))
                }
            )
        }
    }

    @Test("seeded project shows up as a project.created event")
    func projectCreationAppears() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "dashfeed-\(UUID().uuidString.prefix(6))"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="project.created""#))
                    #expect(body.contains("Project \(p.codename) created."))
                    #expect(
                        body.contains(
                            #"href="/admin/projects/\#(p.id?.uuidString ?? "")""#
                        )
                    )
                }
            )
        }
    }

    @Test("seeded person shows up as a person.created event")
    func personCreationAppears() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let person = Person()
            person.name = "Dashfeed Person"
            person.email = "dashfeed-\(UUID().uuidString.prefix(8))@example.com"
            try await person.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="person.created""#))
                    #expect(body.contains("Dashfeed Person added."))
                }
            )
        }
    }

    @Test("seeded inbound mail shows up as an inbox.received event")
    func inboundMailAppears() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let blob = Blob()
            blob.objectStorageUrl = "s3://test/dashfeed-\(UUID().uuidString).eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let m = EmailMessage()
            m.messageId = "<dashfeed-\(UUID().uuidString)@example.com>"
            m.threadId = m.messageId
            m.fromAddress = "outside@example.com"
            m.fromName = "Outside Sender"
            m.toAddress = "support@example.com"
            m.subject = "Dashfeed inbox subject"
            m.receivedAt = Date()
            m.$rawBlob.id = blob.id!
            m.spamVerdict = "PASS"
            m.virusVerdict = "PASS"
            m.dkimVerdict = "PASS"
            m.dmarcVerdict = "PASS"
            try await m.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains(#"data-kind="inbox.received""#))
                    #expect(body.contains("Dashfeed inbox subject"))
                }
            )
        }
    }

    @Test("?since=<future date> drops every event")
    func sinceCutoffFiltersOutOlder() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Project()
            p.codename = "dashfilter-\(UUID().uuidString.prefix(6))"
            try await p.save(on: db)
            // A cutoff a year in the future will exceed every real
            // row's insertedAt timestamp.
            let future = Calendar(identifier: .iso8601).date(
                byAdding: .year,
                value: 1,
                to: Date()
            )!
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let cutoff = formatter.string(from: future)
            try await app.testing().test(
                .GET,
                "/admin?since=\(cutoff)",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(!body.contains("Project \(p.codename) created."))
                    #expect(body.contains("No activity in the selected window."))
                }
            )
        }
    }

    @Test("loadDashboardActivity returns events newest-first")
    func loaderSortsNewestFirst() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let older = Person()
            older.name = "DashOrderOlder"
            older.email = "dashorder-old-\(UUID().uuidString.prefix(6))@example.com"
            try await older.save(on: db)
            let newer = Person()
            newer.name = "DashOrderNewer"
            newer.email = "dashorder-new-\(UUID().uuidString.prefix(6))@example.com"
            try await newer.save(on: db)
            let events = try await loadDashboardActivity(db: db)
            let timestamps = events.map(\.timestamp)
            #expect(timestamps == timestamps.sorted(by: >))
        }
    }

    @Test("loadDashboardActivity respects the limit cap")
    func loaderRespectsLimit() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            for _ in 0..<3 {
                let p = Person()
                p.name = "DashLimit \(UUID().uuidString.prefix(6))"
                p.email = "dashlimit-\(UUID().uuidString.prefix(6))@example.com"
                try await p.save(on: db)
            }
            let events = try await loadDashboardActivity(db: db, limit: 2)
            #expect(events.count == 2)
        }
    }
}
