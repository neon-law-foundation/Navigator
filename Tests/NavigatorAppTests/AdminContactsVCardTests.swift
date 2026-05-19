import FluentKit
import Foundation
import NavigatorDAL
import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Admin: vCard contact export", .serialized)
struct AdminContactsVCardTests {

    @Test("GET /admin/contacts.vcf serves text/vcard with a filename")
    func endpointHeaders() async throws {
        try await withApp(configure: testConfigure) { app in
            try await app.testing().test(
                .GET,
                "/admin/contacts.vcf",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(
                        res.headers.first(name: .contentType)?
                            .lowercased().contains("text/vcard") == true
                    )
                    let disposition = res.headers.first(name: .contentDisposition) ?? ""
                    #expect(disposition.contains("attachment"))
                    #expect(disposition.contains(".vcf"))
                }
            )
        }
    }

    @Test("response body contains BEGIN:VCARD and END:VCARD for each person")
    func bodyContainsVCardBlocks() async throws {
        try await withApp(configure: testConfigure) { app in
            let db = try await app.databaseService!.db
            let p = Person()
            p.name = "Vcard Person"
            p.email = "vcard-\(UUID().uuidString.prefix(6))@example.com"
            try await p.save(on: db)
            try await app.testing().test(
                .GET,
                "/admin/contacts.vcf",
                afterResponse: { res async in
                    let body = res.body.string
                    #expect(body.contains("BEGIN:VCARD"))
                    #expect(body.contains("END:VCARD"))
                    #expect(body.contains("VERSION:4.0"))
                    #expect(body.contains("FN:Vcard Person"))
                    #expect(body.contains(p.email))
                }
            )
        }
    }

    @Test("vCard escapes commas, semicolons, and backslashes in field values")
    func valuesAreEscaped() {
        let person = Person()
        person.name = "Lee, Jordan; Esq.\\Associate"
        person.email = "lee@example.com"
        let body = VCardExporter.render(people: [person])
        #expect(body.contains(#"FN:Lee\, Jordan\; Esq.\\Associate"#))
    }

    @Test("vCard lines end with CRLF as required by RFC 6350")
    func crlfLineEndings() {
        let person = Person()
        person.name = "CRLF Person"
        person.email = "crlf@example.com"
        let body = VCardExporter.render(people: [person])
        // Body must contain CRLF separators; lone-LF indicates a bug.
        #expect(body.contains("\r\n"))
        let stripped = body.replacingOccurrences(of: "\r\n", with: "")
        #expect(!stripped.contains("\n"))
    }

    @Test("filename includes today's UTC date")
    func filenameStamped() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let today = formatter.string(from: Date())
        let name = VCardExporter.filename()
        #expect(name.contains(today))
        #expect(name.hasSuffix(".vcf"))
    }
}
