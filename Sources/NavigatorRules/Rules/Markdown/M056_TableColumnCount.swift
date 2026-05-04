import Foundation

/// M056: Every row of a table must have the same number of cells.
///
/// Mirrors markdownlint's MD056 (table-column-count). The header row sets the expected count;
/// rows with fewer or extra cells are flagged. The delimiter row is validated against the
/// header by `TableTokenizer` (a column-count mismatch there means the lines aren't recognized
/// as a table at all), so this rule only walks body rows.
public struct M056_TableColumnCount: Rule {
    public let code = "M056"
    public let description = "Every row of a table must have the same number of cells"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let tables = TableTokenizer.tokenize(content)

        var violations: [Violation] = []
        for table in tables {
            let expected = table.header.cells.count
            for row in table.body where row.cells.count != expected {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Table row has \(row.cells.count) cell(s); expected \(expected)",
                        line: row.line,
                        context: [
                            "expected": "\(expected)",
                            "actual": "\(row.cells.count)",
                        ]
                    )
                )
            }
        }
        return violations
    }
}
