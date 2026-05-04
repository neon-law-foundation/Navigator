import Foundation

/// M055: Tables must use a consistent leading/trailing pipe style.
///
/// Mirrors markdownlint's MD055 (table-pipe-style) with the default `consistent` style: the
/// header row of the first table in the document establishes the `(leading?, trailing?)` pair,
/// and every row in every table must match.
public struct M055_TablePipeStyle: Rule {
    public let code = "M055"
    public let description = "Tables must use a consistent leading/trailing pipe style"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let tables = TableTokenizer.tokenize(content)
        guard let first = tables.first else { return [] }

        let expectedLeading = first.header.hasLeadingPipe
        let expectedTrailing = first.header.hasTrailingPipe

        var violations: [Violation] = []
        for table in tables {
            for row in table.allRows {
                if row.hasLeadingPipe != expectedLeading
                    || row.hasTrailingPipe != expectedTrailing
                {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Table pipe style does not match the document's first table",
                            line: row.line,
                            context: [
                                "expected": describe(leading: expectedLeading, trailing: expectedTrailing),
                                "actual": describe(leading: row.hasLeadingPipe, trailing: row.hasTrailingPipe),
                            ]
                        )
                    )
                }
            }
        }
        return violations
    }

    private func describe(leading: Bool, trailing: Bool) -> String {
        switch (leading, trailing) {
        case (true, true): return "leading_and_trailing"
        case (true, false): return "leading_only"
        case (false, true): return "trailing_only"
        case (false, false): return "no_leading_or_trailing"
        }
    }
}
