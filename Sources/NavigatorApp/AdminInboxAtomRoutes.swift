import FluentKit
import Foundation
import NavigatorDAL
import Vapor

/// `/admin/inbox.atom` — Atom 1.0 feed of inbound `EmailMessage` rows.
///
/// Operators who watch inbound mail through an RSS reader (NetNewsWire,
/// Reeder, Thunderbird, …) can subscribe to this URL instead of polling
/// the HTML inbox. The feed surfaces the most recent 50 messages,
/// newest-first, with the subject as the entry title and a short body
/// snippet inside `<content type="text">`.
///
/// The feed is intentionally read-only and small — it complements the
/// `/admin/inbox` UI rather than replacing it. Outbound rows are
/// excluded so the feed stays a true "inbox" view.
func registerAdminInboxAtomRoutes(_ app: Application) {
    app.get("admin", "inbox.atom") { req -> Response in
        let databaseService = try requireDatabaseService(req)
        let db = try await databaseService.db
        let rows = try await EmailMessage.query(on: db)
            .sort(\.$receivedAt, .descending)
            .limit(InboxAtomFeed.maxEntries * 2)
            .all()
        let inbound = rows.filter { $0.direction == .inbound }
        let trimmed = Array(inbound.prefix(InboxAtomFeed.maxEntries))
        let xml = InboxAtomFeed.render(messages: trimmed, updated: Date())
        var headers = HTTPHeaders()
        headers.replaceOrAdd(
            name: .contentType,
            value: "application/atom+xml; charset=utf-8"
        )
        return Response(status: .ok, headers: headers, body: .init(string: xml))
    }
}

/// Atom 1.0 (RFC 4287) writer for the inbox feed.
///
/// Kept separate from the route so tests can render against a fixed
/// list of `EmailMessage` rows without spinning Vapor.
enum InboxAtomFeed {

    /// Hard cap on the entry count. RSS readers will typically only
    /// surface 20-50 items so 50 is a useful upper bound that keeps
    /// the response small.
    static let maxEntries = 50

    /// Stable feed identifier. Atom requires a globally-unique `<id>`
    /// — using a `urn:` URI keeps the value independent of the current
    /// hostname or scheme.
    static let feedID = "urn:navigator:admin:inbox"

    /// Returns an RFC 3339 (`yyyy-MM-ddTHH:mm:ssZ`) string for `date`.
    ///
    /// A fresh formatter is created per call so the function stays
    /// Sendable-clean — `ISO8601DateFormatter` is a mutable reference
    /// type and the Swift 6 isolation checker rejects sharing one as a
    /// stored static.
    static func rfc3339(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func render(messages: [EmailMessage], updated: Date) -> String {
        var out =
            #"<?xml version="1.0" encoding="UTF-8"?>"#
            + "\n<feed xmlns=\"http://www.w3.org/2005/Atom\">\n"
        out += "  <title>Inbox</title>\n"
        out += "  <id>\(feedID)</id>\n"
        out += "  <updated>\(rfc3339(updated))</updated>\n"
        out += #"  <link rel="self" href="/admin/inbox.atom" />"# + "\n"
        out += #"  <link rel="alternate" href="/admin/inbox" />"# + "\n"
        for m in messages {
            out += entry(for: m)
        }
        out += "</feed>\n"
        return out
    }

    private static func entry(for message: EmailMessage) -> String {
        let id = message.id?.uuidString ?? UUID().uuidString
        let title = escape(message.subject)
        let author = escape(message.fromName ?? message.fromAddress)
        let summary = escape(snippet(for: message))
        let stamp = rfc3339(message.receivedAt)
        var out = "  <entry>\n"
        out += "    <id>urn:uuid:\(id)</id>\n"
        out += "    <title>\(title)</title>\n"
        out += "    <updated>\(stamp)</updated>\n"
        out += "    <published>\(stamp)</published>\n"
        out += "    <author><name>\(author)</name></author>\n"
        out += #"    <link rel="alternate" href="/admin/inbox/\#(id)" />"# + "\n"
        out += "    <content type=\"text\">\(summary)</content>\n"
        out += "  </entry>\n"
        return out
    }

    /// A 280-character snippet of the text body, falling back to the
    /// subject when no plain-text part is available. The cap keeps the
    /// feed compact for readers showing many entries at once.
    private static func snippet(for message: EmailMessage) -> String {
        let source = message.textBody ?? message.subject
        let cleaned = source.replacingOccurrences(of: "\r\n", with: "\n")
        if cleaned.count <= 280 { return cleaned }
        return String(cleaned.prefix(280)) + "\u{2026}"
    }

    /// Escapes the five XML predefined entities so values land inside
    /// element text / attribute slots without breaking the feed.
    private static func escape(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for ch in value {
            switch ch {
            case "&": out.append("&amp;")
            case "<": out.append("&lt;")
            case ">": out.append("&gt;")
            case "\"": out.append("&quot;")
            case "'": out.append("&apos;")
            default: out.append(ch)
            }
        }
        return out
    }
}
