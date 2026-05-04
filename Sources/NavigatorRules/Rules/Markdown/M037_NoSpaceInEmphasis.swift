import Foundation

/// M037: Emphasis markers must not surround internal whitespace.
///
/// Mirrors markdownlint's MD037 (no-space-in-emphasis). Patterns like `* text *` or
/// `** text **` are stylistic mistakes — CommonMark refuses to treat them as emphasis, and
/// the author usually meant `*text*`. The rule scans for opening/closing marker pairs with a
/// space directly inside, skipping content inside fenced code, indented code, code spans, and
/// frontmatter.
public struct M037_NoSpaceInEmphasis: Rule {
    public let code = "M037"
    public let description = "Emphasis markers must not surround internal whitespace"

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
            violations.append(contentsOf: Self.scan(line: line.raw, lineNumber: line.number))
        }
        return violations
    }

    /// Scan a single line for emphasis marker pairs with internal whitespace.
    static func scan(line: String, lineNumber: Int) -> [Violation] {
        let spans = InlineTokenizer.codeSpans(in: line)
        let codeIdxs = InlineTokenizer.codeSpanCharIndexes(line: line, spans: spans)
        var violations: [Violation] = []
        var masked = Array(line)
        let masker: Character = "\u{1}"

        // Scan strong markers (**/__) before single markers so `** x **` isn't re-matched as
        // nested `* x *`. Masked characters participate in neither lookups nor closer scans.
        let markers: [(String, String)] = [("**", "**"), ("__", "__"), ("*", "*"), ("_", "_")]

        for (open, close) in markers {
            let openChars = Array(open)
            let closeChars = Array(close)
            var i = 0
            while i < masked.count {
                if !canStartMatch(masked, at: i, codeIdxs: codeIdxs, masker: masker) {
                    i += 1
                    continue
                }
                if !startsWith(masked, at: i, seq: openChars) {
                    i += 1
                    continue
                }
                if InlineTokenizer.isEscaped(chars: masked, at: i) {
                    i += 1
                    continue
                }
                // For single-char markers, skip runs of 2+ identical chars — they belong to
                // the strong pass.
                if openChars.count == 1,
                    i + 1 < masked.count, masked[i + 1] == openChars[0]
                {
                    i += 1
                    continue
                }
                guard
                    let closerStart = findCloser(
                        masked: masked,
                        startAt: i + openChars.count,
                        seq: closeChars,
                        codeIdxs: codeIdxs,
                        masker: masker
                    )
                else {
                    i += 1
                    continue
                }
                let innerStart = i + openChars.count
                let innerEnd = closerStart
                let inner = Array(masked[innerStart..<innerEnd])
                let consumedEnd = closerStart + closeChars.count
                // Empty or all-whitespace content isn't intended emphasis — mask and move on.
                let allWhitespaceOrEmpty =
                    inner.isEmpty || inner.allSatisfy { $0.isWhitespace }
                if !allWhitespaceOrEmpty {
                    let leading = inner.first?.isWhitespace == true
                    let trailing = inner.last?.isWhitespace == true
                    if leading || trailing {
                        violations.append(
                            Violation(
                                ruleCode: "M037",
                                message: "Space inside emphasis markers",
                                line: lineNumber,
                                context: ["marker": open]
                            )
                        )
                    }
                }
                for k in i..<consumedEnd { masked[k] = masker }
                i = consumedEnd
            }
        }
        return violations
    }

    private static func canStartMatch(
        _ array: [Character],
        at index: Int,
        codeIdxs: Set<Int>,
        masker: Character
    ) -> Bool {
        if codeIdxs.contains(index) { return false }
        if array[index] == masker { return false }
        return true
    }

    private static func findCloser(
        masked: [Character],
        startAt: Int,
        seq: [Character],
        codeIdxs: Set<Int>,
        masker: Character
    ) -> Int? {
        var j = startAt
        while j < masked.count {
            if !canStartMatch(masked, at: j, codeIdxs: codeIdxs, masker: masker) {
                j += 1
                continue
            }
            if !startsWith(masked, at: j, seq: seq) {
                j += 1
                continue
            }
            if InlineTokenizer.isEscaped(chars: masked, at: j) {
                j += 1
                continue
            }
            // Single-char markers must not be part of a longer run.
            if seq.count == 1, j + 1 < masked.count, masked[j + 1] == seq[0] {
                j += 1
                continue
            }
            return j
        }
        return nil
    }

    private static func startsWith(_ array: [Character], at index: Int, seq: [Character]) -> Bool {
        guard index + seq.count <= array.count else { return false }
        for (offset, ch) in seq.enumerated() where array[index + offset] != ch {
            return false
        }
        return true
    }
}
