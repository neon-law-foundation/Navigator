import Foundation

/// M034: URLs in prose must be wrapped in angle brackets or a markdown link destination.
///
/// Mirrors markdownlint's MD034 (no-bare-urls). Uses `BlockTokenizer` to skip lines inside
/// fenced code, indented code, and YAML frontmatter where URLs are intentional and should not
/// be flagged.
public struct M034_NoBareURLs: Rule {
    public let code = "M034"
    public let description = "URLs must be wrapped in angle brackets or a link"

    private static let protocols = ["http://", "https://", "ftp://"]

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let skippedLines = Self.linesInsideCodeOrFrontmatter(content: content)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) {
            if skippedLines.contains(line.number) { continue }
            if line.isInFrontmatter { continue }
            for range in Self.bareURLRanges(in: line.raw) {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Bare URL used — wrap in <...> or a markdown link",
                        line: line.number,
                        context: ["url": String(line.raw[range])]
                    )
                )
            }
        }
        return violations
    }

    /// Collect every 1-indexed line that sits inside a fenced or indented code block, or
    /// the top-level frontmatter block, so the line-scan pass can skip them.
    private static func linesInsideCodeOrFrontmatter(content: String) -> Set<Int> {
        var skipped: Set<Int> = []
        for block in BlockTokenizer.tokenize(content) {
            switch block.kind {
            case .fencedCode, .indentedCode, .frontmatter:
                for line in block.startLine...block.endLine {
                    skipped.insert(line)
                }
            default:
                continue
            }
        }
        return skipped
    }

    /// Enumerate string ranges in `line` that look like bare URLs: URL-like substrings that
    /// are not immediately surrounded by angle brackets or a markdown link destination.
    static func bareURLRanges(in line: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var cursor = line.startIndex
        while cursor < line.endIndex {
            guard let match = nextURLMatch(in: line, from: cursor) else { break }
            if !isWrapped(in: line, range: match) {
                ranges.append(match)
            }
            cursor = match.upperBound
        }
        return ranges
    }

    /// Find the next URL-like substring starting at or after `position`.
    private static func nextURLMatch(
        in line: String,
        from position: String.Index
    ) -> Range<String.Index>? {
        var best: Range<String.Index>?
        for scheme in protocols {
            guard let schemeRange = line.range(of: scheme, range: position..<line.endIndex)
            else { continue }
            var end = schemeRange.upperBound
            while end < line.endIndex, !isURLTerminator(line[end]) {
                end = line.index(after: end)
            }
            // Strip trailing punctuation that is almost always sentence-terminal, not part of the URL.
            while end > schemeRange.upperBound {
                let prev = line.index(before: end)
                let ch = line[prev]
                if ch == "." || ch == "," || ch == ";" || ch == ":" || ch == "!" || ch == "?" {
                    end = prev
                } else {
                    break
                }
            }
            let candidate = schemeRange.lowerBound..<end
            if best == nil || candidate.lowerBound < best!.lowerBound {
                best = candidate
            }
        }
        return best
    }

    private static func isURLTerminator(_ ch: Character) -> Bool {
        ch.isWhitespace || ch == ">" || ch == ")" || ch == "\"" || ch == "'"
    }

    /// True when the URL at `range` is already wrapped in `<>` or sits inside a markdown
    /// link destination `](...)` / reference-style `]:`.
    private static func isWrapped(in line: String, range: Range<String.Index>) -> Bool {
        if isAngleBracketed(in: line, range: range) { return true }
        if isInLinkDestination(in: line, range: range) { return true }
        if isInReferenceDefinition(in: line, range: range) { return true }
        return false
    }

    private static func isAngleBracketed(in line: String, range: Range<String.Index>) -> Bool {
        guard range.lowerBound > line.startIndex, range.upperBound < line.endIndex else {
            return false
        }
        return line[line.index(before: range.lowerBound)] == "<"
            && line[range.upperBound] == ">"
    }

    private static func isInLinkDestination(in line: String, range: Range<String.Index>) -> Bool {
        guard range.lowerBound > line.startIndex else { return false }
        let openParen = line.index(before: range.lowerBound)
        guard line[openParen] == "(", openParen > line.startIndex else { return false }
        return line[line.index(before: openParen)] == "]"
    }

    private static func isInReferenceDefinition(in line: String, range: Range<String.Index>) -> Bool {
        let beforeURL = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        return beforeURL.hasPrefix("[") && beforeURL.hasSuffix("]:")
    }
}
