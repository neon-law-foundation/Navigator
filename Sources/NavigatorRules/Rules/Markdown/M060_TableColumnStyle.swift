import Foundation

/// M060: Tables must use a consistent column-padding style.
///
/// Mirrors markdownlint's MD060 (table-column-style) with the default `any` style: a table is
/// flagged only when none of `tight`, `compact`, or `aligned` matches every row. The check is
/// per-table, not document-wide — different tables may pick different styles.
///
/// Definitions used for the match:
///
/// * **tight** — each cell has exactly one space of padding on each side adjacent to a pipe
///   (`| cell |`).
/// * **compact** — each cell has zero spaces of padding adjacent to a pipe (`|cell|`).
/// * **aligned** — every pipe in column N appears at the same character offset across all rows.
///   Cell content is ignored; only the pipe positions matter.
///
/// A row's leading/trailing pipe presence is *not* checked here — that's M055's job.
public struct M060_TableColumnStyle: Rule {
    public let code = "M060"
    public let description = "Tables must use a consistent column-padding style"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let tables = TableTokenizer.tokenize(content)

        var violations: [Violation] = []
        for table in tables {
            if matchesAligned(table) { continue }
            if matchesTight(table) { continue }
            if matchesCompact(table) { continue }
            violations.append(
                Violation(
                    ruleCode: code,
                    message: "Table does not match any consistent column style (aligned/tight/compact)",
                    line: table.startLine
                )
            )
        }
        return violations
    }

    /// All rows must share the same set of pipe character offsets.
    private func matchesAligned(_ table: Table) -> Bool {
        let target = table.header.pipePositions
        for row in table.allRows where row.pipePositions != target { return false }
        return true
    }

    /// Every cell must have exactly one space of padding on each adjacent-to-pipe side.
    private func matchesTight(_ table: Table) -> Bool {
        for row in table.allRows {
            for cell in row.cells where !hasOneSpacePadding(cell) { return false }
        }
        return true
    }

    /// Every cell must have zero spaces of padding adjacent to its pipes.
    private func matchesCompact(_ table: Table) -> Bool {
        for row in table.allRows {
            for cell in row.cells where !hasNoPadding(cell) { return false }
        }
        return true
    }

    /// True when `cell` has the form `␣X␣` where `X` is non-empty and contains no leading or
    /// trailing space. An empty cell (whitespace-only) is treated as matching to keep degenerate
    /// rows from forcing a violation.
    private func hasOneSpacePadding(_ cell: String) -> Bool {
        if cell.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        guard cell.hasPrefix(" "), cell.hasSuffix(" ") else { return false }
        if cell.hasPrefix("  ") { return false }
        if cell.hasSuffix("  ") { return false }
        return true
    }

    /// True when `cell` has no leading or trailing whitespace. An empty cell is allowed.
    private func hasNoPadding(_ cell: String) -> Bool {
        if cell.isEmpty { return true }
        if cell.first == " " || cell.first == "\t" { return false }
        if cell.last == " " || cell.last == "\t" { return false }
        return true
    }
}
