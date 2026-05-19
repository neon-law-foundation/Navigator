import Foundation
import Vapor

/// RFC 4180 CSV writer for admin index pages.
///
/// `render(header:rows:)` joins a string-shaped grid into a CSV body
/// with `\r\n` line endings and per-field escaping. Each row must have
/// the same length as the header; callers guarantee that.
///
/// `filenameStamp(for:)` formats today's date as `YYYY-MM-DD` for use
/// in the `Content-Disposition: attachment; filename=…` header.
enum AdminCSVExport {

    /// Joins a header row and a data grid into a CSV body. Fields that
    /// contain a comma, a double-quote, a `\n`, or a `\r` are wrapped
    /// in double-quotes and internal double-quotes are doubled, per
    /// RFC 4180.
    static func render(header: [String], rows: [[String]]) -> String {
        var lines: [String] = []
        lines.append(header.map(escape).joined(separator: ","))
        for row in rows {
            lines.append(row.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Calendar-date stamp (UTC) for filenames. Independent of the
    /// system locale so two callers on different machines produce the
    /// same string for the same point in time.
    static func filenameStamp(for date: Date = Date()) -> String {
        Self.dateFormatter.string(from: date)
    }

    /// Builds a Vapor `Response` for a CSV body with the right MIME
    /// type and a download-friendly `Content-Disposition` filename.
    static func response(
        body: String,
        filename: String
    ) -> Response {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: "text/csv; charset=utf-8")
        headers.replaceOrAdd(
            name: .contentDisposition,
            value: #"attachment; filename="\#(filename)""#
        )
        return Response(status: .ok, headers: headers, body: .init(string: body))
    }

    private static let specialCharacters: Set<Character> = [",", "\"", "\n", "\r"]

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Escapes one field. If the field contains nothing that would
    /// confuse a CSV parser, it is returned untouched.
    private static func escape(_ field: String) -> String {
        guard field.contains(where: Self.specialCharacters.contains) else {
            return field
        }
        let doubled = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(doubled)\""
    }
}
