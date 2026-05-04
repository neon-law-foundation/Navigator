import Foundation

/// M058: Tables must be preceded and followed by a blank line.
///
/// Mirrors markdownlint's MD058 (blanks-around-tables). Tables at the document's start or end
/// are exempt. A non-blank line directly *before* a table is always a violation. A non-blank
/// line directly *after* a table is only a violation when it begins another structural block
/// (heading, hr, fenced code, blockquote, list, another table) — paragraph text immediately
/// after a table is consumed by the GFM parser as part of the table itself, so flagging it
/// would produce false positives.
public struct M058_BlanksAroundTables: Rule {
    public let code = "M058"
    public let description = "Tables must be preceded and followed by a blank line"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let rawLines = content.components(separatedBy: .newlines)
        let lines: [String]
        if content.hasSuffix("\n"), rawLines.last == "" {
            lines = Array(rawLines.dropLast())
        } else {
            lines = rawLines
        }

        let tables = TableTokenizer.tokenize(content)
        let tableLineSet: Set<Int> = Set(tables.flatMap { Array($0.startLine...$0.endLine) })

        var violations: [Violation] = []
        for table in tables {
            if table.startLine > 1 {
                let prevIndex = table.startLine - 2
                if prevIndex >= 0, !isBlank(lines[prevIndex]) {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Table is not preceded by a blank line",
                            line: table.startLine
                        )
                    )
                }
            }
            let nextIndex = table.endLine
            if nextIndex < lines.count {
                let nextLine = lines[nextIndex]
                if !isBlank(nextLine),
                    startsStructuralBlock(line: nextLine, lineNumber: nextIndex + 1, inTableLines: tableLineSet)
                {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Table is not followed by a blank line",
                            line: table.endLine
                        )
                    )
                }
            }
        }
        return violations
    }

    private func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// True when `line` starts a structural block (heading, hr, fenced code, blockquote, list,
    /// or another table). Paragraph text returns false — GFM absorbs trailing paragraphs into
    /// the table.
    private func startsStructuralBlock(line: String, lineNumber: Int, inTableLines: Set<Int>) -> Bool {
        if inTableLines.contains(lineNumber) { return true }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") { return true }
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { return true }
        if trimmed.hasPrefix(">") { return true }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return true
        }
        if let first = trimmed.first, first.isNumber {
            // Match `1.` or `1)` followed by whitespace.
            var seenDigit = false
            for ch in trimmed {
                if ch.isNumber {
                    seenDigit = true
                    continue
                }
                if seenDigit, ch == ".",
                    trimmed.dropFirst(trimmed.distance(from: trimmed.startIndex, to: trimmed.firstIndex(of: ch)!) + 1)
                        .first == " "
                {
                    return true
                }
                break
            }
        }
        if isHorizontalRule(trimmed) { return true }
        return false
    }

    private func isHorizontalRule(_ trimmed: String) -> Bool {
        guard let first = trimmed.first, first == "-" || first == "*" || first == "_" else {
            return false
        }
        var count = 0
        for ch in trimmed {
            if ch == first {
                count += 1
            } else if ch != " " && ch != "\t" {
                return false
            }
        }
        return count >= 3
    }
}
