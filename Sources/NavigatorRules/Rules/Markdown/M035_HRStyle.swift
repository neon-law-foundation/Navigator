import Foundation

/// M035: Horizontal rules must use a consistent style within a file.
///
/// Mirrors markdownlint's MD035 (hr-style) with the default `style: "consistent"`:
/// the first HR in the file sets the expected style; later HRs that differ are flagged.
public struct M035_HRStyle: Rule {
    public let code = "M035"
    public let description = "Horizontal rules must use a consistent style"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        var violations: [Violation] = []
        var expectedStyle: String?
        for line in LineScanner.scan(content) where !line.isInFrontmatter {
            guard let style = Self.horizontalRuleStyle(of: line.raw) else { continue }
            if let expected = expectedStyle {
                if style != expected {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Horizontal rule style does not match first use",
                            line: line.number,
                            context: ["expected": expected, "actual": style]
                        )
                    )
                }
            } else {
                expectedStyle = style
            }
        }
        return violations
    }

    /// Return the canonical style string of a horizontal rule line (the trimmed line),
    /// or `nil` when the line is not a horizontal rule.
    private static func horizontalRuleStyle(of line: String) -> String? {
        // Up to three leading spaces allowed.
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex else { return nil }
        let marker = line[cursor]
        guard marker == "-" || marker == "*" || marker == "_" else { return nil }

        var symbolCount = 0
        var sawOnlyWhitespaceBetween = true
        var seen = cursor
        while seen < line.endIndex {
            let ch = line[seen]
            if ch == marker {
                symbolCount += 1
            } else if ch == " " || ch == "\t" {
                // whitespace between markers is fine
            } else {
                sawOnlyWhitespaceBetween = false
                break
            }
            seen = line.index(after: seen)
        }
        guard sawOnlyWhitespaceBetween, symbolCount >= 3 else { return nil }
        return line.trimmingCharacters(in: .whitespaces)
    }
}
