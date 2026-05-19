import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: Inbox Atom feed", .serialized)
struct AdminInboxAtomTests {

    @Test("GET /admin/inbox.atom serves application/atom+xml")
    func contentTypeHeader() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/inbox.atom",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(
                        res.headers.first(name: .contentType)?
                            .lowercased().contains("application/atom+xml") == true
                    )
                }
            )
        }
    }

    @Test("feed contains the Atom envelope and a stable id")
    func envelope() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/inbox.atom",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("<?xml"))
                    #expect(body.contains(#"<feed xmlns="http://www.w3.org/2005/Atom">"#))
                    #expect(body.contains("<id>urn:navigator:admin:inbox</id>"))
                    #expect(body.contains(#"<link rel="self" href="/admin/inbox.atom" />"#))
                }
            )
        }
    }

    @Test("seeded inbound message appears as an entry with its subject and link")
    func seededEntryRenders() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let blob = Blob()
            blob.objectStorageUrl = "s3://test/atom-\(UUID().uuidString).eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let m = EmailMessage()
            m.messageId = "<atom-\(UUID().uuidString)@example.com>"
            m.threadId = m.messageId
            m.fromAddress = "outside@example.com"
            m.fromName = "Atom Tester"
            m.toAddress = "support@example.com"
            m.subject = "Atom feed subject line"
            m.textBody = "Plain-text body for the snippet."
            m.receivedAt = Date()
            m.$rawBlob.id = blob.id!
            m.spamVerdict = "PASS"
            m.virusVerdict = "PASS"
            m.dkimVerdict = "PASS"
            m.dmarcVerdict = "PASS"
            try await m.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/inbox.atom",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("<title>Atom feed subject line</title>"))
                    #expect(body.contains("urn:uuid:\(m.id!.uuidString)"))
                    #expect(body.contains("/admin/inbox/\(m.id!.uuidString)"))
                    #expect(body.contains("Plain-text body for the snippet."))
                }
            )
        }
    }

    @Test("XML special characters in subjects are escaped")
    func escapesXMLEntities() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let blob = Blob()
            blob.objectStorageUrl = "s3://test/atom-esc-\(UUID().uuidString).eml"
            blob.referencedBy = .emailMessages
            blob.referencedById = UUID()
            try await blob.save(on: db)
            let m = EmailMessage()
            m.messageId = "<atom-esc-\(UUID().uuidString)@example.com>"
            m.threadId = m.messageId
            m.fromAddress = "outside@example.com"
            m.toAddress = "support@example.com"
            m.subject = "Tom & Jerry <script>alert(1)</script>"
            m.receivedAt = Date()
            m.$rawBlob.id = blob.id!
            m.spamVerdict = "PASS"
            m.virusVerdict = "PASS"
            m.dkimVerdict = "PASS"
            m.dmarcVerdict = "PASS"
            try await m.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/inbox.atom",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(
                        body.contains(
                            "Tom &amp; Jerry &lt;script&gt;alert(1)&lt;/script&gt;"
                        )
                    )
                    // A raw < script > tag would break XML parsers and
                    // surface in a reader as live markup — verify the
                    // unescaped form is absent.
                    #expect(!body.contains("<script>alert(1)</script>"))
                }
            )
        }
    }
}
