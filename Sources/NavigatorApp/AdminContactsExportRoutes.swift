import FluentKit
import Foundation
import NavigatorDAL
import Vapor

/// `/admin/contacts.vcf` — RFC 6350 vCard 4.0 download for every Person
/// row, suitable for importing into Contacts apps on iOS, macOS, and
/// Android.
///
/// The export is intentionally minimal: one `VCARD` block per Person
/// with the formatted name (`FN`) and email address (`EMAIL`). vCard
/// 4.0 specifies CRLF line endings and value escaping for `,`, `;`, and
/// newline characters; both are honored here.
///
/// `Content-Disposition: attachment` and the `.vcf` filename make the
/// browser treat the response as a download instead of trying to render
/// it inline.
func registerAdminContactsExportRoutes(_ app: Application) {
    app.get("admin", "contacts.vcf") { req -> Response in
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let people = try await Person.query(on: db)
            .sort(\.$name, .ascending)
            .all()
        let body = VCardExporter.render(people: people)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(
            name: .contentType,
            value: "text/vcard; charset=utf-8"
        )
        headers.replaceOrAdd(
            name: .contentDisposition,
            value: "attachment; filename=\"\(VCardExporter.filename())\""
        )
        return Response(status: .ok, headers: headers, body: .init(string: body))
    }
}

/// RFC 6350 vCard 4.0 writer.
///
/// Kept separate from the route so tests can render against a fixed list
/// of `Person` rows without spinning the Vapor stack.
enum VCardExporter {

    /// Renders `people` as a concatenated vCard 4.0 document.
    static func render(people: [Person]) -> String {
        people.map(vcard(for:)).joined()
    }

    /// File name stamp written into the `Content-Disposition` header.
    /// Includes today's UTC date so a folder of stamps stays in order.
    static func filename(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "navigator-contacts-\(formatter.string(from: now)).vcf"
    }

    private static func vcard(for person: Person) -> String {
        let name = escape(person.name)
        let email = escape(person.email)
        // RFC 6350 §3.3 mandates CRLF line endings. The "kind:individual"
        // property hints that the record is a single human rather than a
        // group, which iOS uses to decide how to present the entry.
        return [
            "BEGIN:VCARD",
            "VERSION:4.0",
            "KIND:individual",
            "FN:\(name)",
            "EMAIL;TYPE=work:\(email)",
            "END:VCARD",
        ].joined(separator: "\r\n") + "\r\n"
    }

    /// vCard property values escape `\`, `,`, `;`, and CR/LF.
    private static func escape(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for ch in value {
            switch ch {
            case "\\": out.append("\\\\")
            case ",": out.append("\\,")
            case ";": out.append("\\;")
            case "\n": out.append("\\n")
            case "\r": continue
            default: out.append(ch)
            }
        }
        return out
    }
}
