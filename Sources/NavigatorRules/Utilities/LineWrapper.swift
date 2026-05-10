import Foundation

/// Deterministic Markdown line-wrapping used by S101's auto-fix.
///
/// Wraps long lines at the last whitespace boundary that keeps the line at or
/// below `maxLength` columns. Preserves structures whose layout cannot be
/// reflowed without changing meaning:
///
/// - Fenced code blocks (```` ``` ```` and `~~~`)
/// - Pipe tables (lines starting with `|`)
/// - Reference-style link definitions (`[label]: url …`)
/// - Inline HTML blocks (lines starting with `<`)
/// - ATX headings (`#`-prefixed)
/// - Horizontal rules (`---`, `***`, `___`)
///
/// Blockquote (`> `) and list-item (`- `, `* `, `+ `, `\d+. `) lines are
/// wrapped with a continuation prefix that matches the original prefix's
/// width, keeping wrapped text visually aligned under the marker.
public enum LineWrapper {
    /// The default maximum line length matching ``S101_LineLength``.
    public static let defaultMaxLength = 120

    /// Wrap every paragraph line in `content` to no more than `maxLength`
    /// columns. Returns the rewrapped content.
    ///
    /// A single token wider than `maxLength` (a long URL, a hash) is emitted
    /// on its own line and left intact rather than broken mid-word.
    public static func wrap(_ content: String, maxLength: Int = defaultMaxLength) -> String {
        var result: [String] = []
        var fenceMarker: String?

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let marker = fenceMarker {
                if trimmed.hasPrefix(marker) {
                    fenceMarker = nil
                }
                result.append(line)
                continue
            }

            if trimmed.hasPrefix("```") {
                fenceMarker = "```"
                result.append(line)
                continue
            }
            if trimmed.hasPrefix("~~~") {
                fenceMarker = "~~~"
                result.append(line)
                continue
            }

            if line.count <= maxLength || shouldSkipWrap(line) {
                result.append(line)
                continue
            }

            result.append(contentsOf: wrapLine(line, maxLength: maxLength))
        }

        return result.joined(separator: "\n")
    }

    private static func shouldSkipWrap(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("|") { return true }
        if trimmed.hasPrefix("#") { return true }
        if trimmed.hasPrefix("<") { return true }

        if trimmed.range(of: #"^\[[^\]]+\]:\s"#, options: .regularExpression) != nil {
            return true
        }
        if trimmed.range(of: #"^([-*_])(\s*\1){2,}\s*$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func wrapLine(_ line: String, maxLength: Int) -> [String] {
        let (prefix, body) = splitPrefix(line)
        let continuation = continuationPrefix(for: prefix)

        let words = body.split(
            whereSeparator: { $0 == " " || $0 == "\t" }
        ).map(String.init)

        guard !words.isEmpty else {
            return [line]
        }

        var lines: [String] = []
        var current = prefix + words[0]

        for word in words.dropFirst() {
            let candidate = current + " " + word
            if candidate.count <= maxLength {
                current = candidate
            } else {
                lines.append(current)
                current = continuation + word
            }
        }
        lines.append(current)
        return lines
    }

    private static func splitPrefix(_ line: String) -> (prefix: String, body: String) {
        let pattern = #"^(\s*(?:[-*+]\s+|\d+\.\s+|>\s+)?)(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return ("", line)
        }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard
            let match = regex.firstMatch(in: line, range: range),
            match.numberOfRanges >= 3
        else {
            return ("", line)
        }
        let prefix = nsLine.substring(with: match.range(at: 1))
        let body = nsLine.substring(with: match.range(at: 2))
        return (prefix, body)
    }

    private static func continuationPrefix(for prefix: String) -> String {
        if prefix.contains(">") {
            return String(prefix.map { $0 == ">" || $0.isWhitespace ? $0 : " " })
        }
        return String(repeating: " ", count: prefix.count)
    }
}
