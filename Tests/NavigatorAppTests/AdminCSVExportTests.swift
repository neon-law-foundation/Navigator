import Foundation
import Testing

@testable import NavigatorApp

@Suite("AdminCSVExport value type")
struct AdminCSVExportValueTests {

    @Test("renders header + rows joined by CRLF per RFC 4180")
    func basicRender() {
        let body = AdminCSVExport.render(
            header: ["a", "b"],
            rows: [
                ["1", "2"],
                ["3", "4"],
            ]
        )
        #expect(body == "a,b\r\n1,2\r\n3,4\r\n")
    }

    @Test("escapes fields containing commas, double-quotes, and newlines")
    func escapesSpecialCharacters() {
        let body = AdminCSVExport.render(
            header: ["name", "note"],
            rows: [
                ["needs, escape", "has \"quote\""],
                ["multi\nline", "plain"],
            ]
        )
        // The first row has a comma -> wrapped in quotes; the second
        // column has an embedded quote -> doubled and the whole field
        // wrapped. Third row has a newline -> wrapped. Fourth is plain.
        #expect(body.contains(#""needs, escape""#))
        #expect(body.contains(#""has ""quote""""#))
        #expect(body.contains(#""multi"#))
    }

    @Test("empty rows array still emits the header row")
    func emptyRowsKeepsHeader() {
        let body = AdminCSVExport.render(header: ["a", "b"], rows: [])
        #expect(body == "a,b\r\n")
    }

    @Test("filenameStamp returns YYYY-MM-DD for the given date in UTC")
    func filenameStampUTC() {
        let date = Date(timeIntervalSince1970: 1_704_067_200)  // 2024-01-01 UTC
        #expect(AdminCSVExport.filenameStamp(for: date) == "2024-01-01")
    }
}
