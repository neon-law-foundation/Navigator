import Foundation

/// M011: Links must not use the reversed `(text)[url]` form.
///
/// Mirrors markdownlint's MD011 (no-reversed-links). Authors sometimes swap `[]` and `()`
/// producing `(text)[url]` which renders as literal text. Detection looks for `)[` with
/// plausible text/url content on either side, anchored on a paragraph line and outside
/// code spans.
public struct M011_NoReversedLinks: Rule {
    public let code = "M011"
    public let description = "Links must use [text](url), not (text)[url]"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let skipLines = ReferenceCollector.linesToSkip(content: content)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) {
            if skipLines.contains(line.number) { continue }
            if line.isInFrontmatter { continue }
            if Self.hasReversedLink(in: line.raw) {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Reversed link syntax: use [text](url)",
                        line: line.number
                    )
                )
            }
        }
        return violations
    }

    /// True when `line` contains a `(…)[…]` shape outside of code spans.
    static func hasReversedLink(in line: String) -> Bool {
        let spans = InlineTokenizer.codeSpans(in: line)
        let codeIdxs = InlineTokenizer.codeSpanCharIndexes(line: line, spans: spans)
        let chars = Array(line)

        var i = 0
        while i < chars.count {
            if codeIdxs.contains(i) {
                i += 1
                continue
            }
            if chars[i] == "(", !InlineTokenizer.isEscaped(chars: chars, at: i) {
                var j = i + 1
                var depth = 1
                while j < chars.count, depth > 0 {
                    if codeIdxs.contains(j) {
                        j += 1
                        continue
                    }
                    let ch = chars[j]
                    if ch == "(", !InlineTokenizer.isEscaped(chars: chars, at: j) {
                        depth += 1
                    } else if ch == ")", !InlineTokenizer.isEscaped(chars: chars, at: j) {
                        depth -= 1
                        if depth == 0 { break }
                    }
                    j += 1
                }
                if j < chars.count, depth == 0 {
                    let after = j + 1
                    if after < chars.count, chars[after] == "[" {
                        var k = after + 1
                        var bracketDepth = 1
                        while k < chars.count, bracketDepth > 0 {
                            if codeIdxs.contains(k) {
                                k += 1
                                continue
                            }
                            if chars[k] == "[",
                                !InlineTokenizer.isEscaped(chars: chars, at: k)
                            {
                                bracketDepth += 1
                            } else if chars[k] == "]",
                                !InlineTokenizer.isEscaped(chars: chars, at: k)
                            {
                                bracketDepth -= 1
                                if bracketDepth == 0 { break }
                            }
                            k += 1
                        }
                        if k < chars.count, bracketDepth == 0 {
                            let text = chars[(i + 1)..<j]
                            let url = chars[(after + 1)..<k]
                            if !text.isEmpty, !url.isEmpty {
                                return true
                            }
                        }
                    }
                }
            }
            i += 1
        }
        return false
    }
}
