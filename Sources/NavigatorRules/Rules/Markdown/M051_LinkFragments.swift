import Foundation

/// M051: Link fragments (`#fragment`) must match a heading in the document.
///
/// Mirrors markdownlint's MD051 (link-fragments). The rule computes the GitHub-flavored slug
/// for every heading in the document, then reports any inline-link or reference-definition
/// fragment that doesn't resolve to that set.
///
/// Slug rules (matching GitHub's implementation):
///
/// * Lowercase the heading text.
/// * Replace whitespace with `-`.
/// * Strip punctuation other than `-` and `_`.
/// * Collapse runs of consecutive `-` / leading trailing `-` remain as produced.
///
/// Pure-anchor fragments (`#top`, empty fragment from `()`) and fragments that point at another
/// document (`other.md#foo`) are skipped — only same-document `#`-prefixed fragments are checked.
public struct M051_LinkFragments: Rule {
    public let code = "M051"
    public let description = "Link fragments must match a heading in the document"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let slugs = Self.headingSlugs(in: content)
        let skipLines = ReferenceCollector.linesToSkip(content: content)

        var violations: [Violation] = []
        let lines = content.components(separatedBy: "\n")
        for (idx, line) in lines.enumerated() {
            let number = idx + 1
            if skipLines.contains(number) { continue }
            for fragment in Self.fragmentsIn(line: line) {
                if Self.isSkippable(fragment: fragment) { continue }
                let slug = Self.slugify(fragment)
                if !slugs.contains(slug) {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Link fragment does not match any heading",
                            line: number,
                            context: ["fragment": fragment]
                        )
                    )
                }
            }
        }
        return violations
    }

    /// GitHub-flavored slug for a heading text. Exposed for tests.
    public static func slugify(_ raw: String) -> String {
        var result = ""
        let lowered = raw.lowercased()
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                result.append(ch)
            } else if ch == "-" || ch == "_" {
                result.append(ch)
            } else if ch.isWhitespace {
                result.append("-")
            }
        }
        return result
    }

    /// Slugs for every heading in the document, derived from `BlockTokenizer`.
    static func headingSlugs(in content: String) -> Set<String> {
        var slugs: Set<String> = []
        for block in BlockTokenizer.tokenize(content) {
            if case .heading(_, _, let text) = block.kind {
                let clean = InlineTokenizer.stripInlineMarkup(text)
                slugs.insert(slugify(clean))
            }
        }
        return slugs
    }

    /// Extract all `#fragment` strings from a line's link destinations. Covers inline
    /// `[text](#frag)` and reference-definition `[label]: #frag` forms.
    static func fragmentsIn(line: String) -> [String] {
        var fragments: [String] = []
        let codeSpans = InlineTokenizer.codeSpans(in: line)
        let codeIdxs = InlineTokenizer.codeSpanCharIndexes(line: line, spans: codeSpans)

        var cursor = 0
        let chars = Array(line)
        while cursor < chars.count {
            if codeIdxs.contains(cursor) {
                cursor += 1
                continue
            }
            if chars[cursor] == "]", cursor + 1 < chars.count, chars[cursor + 1] == "(" {
                var j = cursor + 2
                var depth = 1
                let destStart = j
                while j < chars.count, depth > 0 {
                    if chars[j] == "(" {
                        depth += 1
                    } else if chars[j] == ")" {
                        depth -= 1
                        if depth == 0 { break }
                    }
                    j += 1
                }
                if j <= chars.count, depth == 0 {
                    let dest = String(chars[destStart..<j]).trimmingCharacters(in: .whitespaces)
                    if let fragment = extractSameDocFragment(from: dest) {
                        fragments.append(fragment)
                    }
                    cursor = j + 1
                    continue
                }
            }
            cursor += 1
        }

        if let def = parseReferenceDestination(line: line),
            let fragment = extractSameDocFragment(from: def)
        {
            fragments.append(fragment)
        }
        return fragments
    }

    private static func extractSameDocFragment(from dest: String) -> String? {
        var trimmed = dest
        if trimmed.hasPrefix("<"), trimmed.hasSuffix(">") {
            trimmed = String(trimmed.dropFirst().dropLast())
        }
        guard let hashPos = trimmed.firstIndex(of: "#") else { return nil }
        // If there's a non-empty part before the `#`, it's a different document — skip.
        let beforeHash = trimmed[..<hashPos]
        if !beforeHash.isEmpty { return nil }
        let fragment = String(trimmed[trimmed.index(after: hashPos)...])
        return fragment
    }

    private static func parseReferenceDestination(line: String) -> String? {
        var cursor = line.startIndex
        var indent = 0
        while cursor < line.endIndex, line[cursor] == " ", indent < 3 {
            cursor = line.index(after: cursor)
            indent += 1
        }
        guard cursor < line.endIndex, line[cursor] == "[" else { return nil }
        cursor = line.index(after: cursor)
        while cursor < line.endIndex, line[cursor] != "]" {
            if line[cursor] == "\\", line.index(after: cursor) < line.endIndex {
                cursor = line.index(after: cursor)
            }
            cursor = line.index(after: cursor)
        }
        guard cursor < line.endIndex, line[cursor] == "]" else { return nil }
        cursor = line.index(after: cursor)
        guard cursor < line.endIndex, line[cursor] == ":" else { return nil }
        cursor = line.index(after: cursor)
        while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
            cursor = line.index(after: cursor)
        }
        let destStart = cursor
        while cursor < line.endIndex, line[cursor] != " ", line[cursor] != "\t" {
            cursor = line.index(after: cursor)
        }
        let dest = String(line[destStart..<cursor])
        return dest.isEmpty ? nil : dest
    }

    /// Fragments that the rule intentionally allows regardless of heading presence — `top` is
    /// GitHub's special anchor and pure-empty fragments indicate "this page".
    private static func isSkippable(fragment: String) -> Bool {
        let trimmed = fragment.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        if trimmed == "top" { return true }
        return false
    }
}
