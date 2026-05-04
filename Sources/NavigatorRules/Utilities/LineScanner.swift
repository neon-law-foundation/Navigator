import Foundation

/// A single scanned line with metadata useful to line-based linting rules.
public struct ScannedLine: Equatable, Sendable {
    /// 1-indexed line number.
    public let number: Int

    /// The raw line content (without the trailing newline).
    public let raw: String

    /// Whether the line is blank (empty or whitespace only).
    public let isBlank: Bool

    /// Whether the line falls inside the top YAML frontmatter block delimited by `---`.
    /// The opening and closing `---` delimiter lines are *not* considered inside the block.
    public let isInFrontmatter: Bool

    public init(number: Int, raw: String, isBlank: Bool, isInFrontmatter: Bool) {
        self.number = number
        self.raw = raw
        self.isBlank = isBlank
        self.isInFrontmatter = isInFrontmatter
    }

    /// The raw line with leading and trailing whitespace removed.
    public var trimmed: String {
        raw.trimmingCharacters(in: .whitespaces)
    }
}

/// Shared line-by-line scanning helper used by line-scan linting rules.
public enum LineScanner {
    /// Split `content` into lines and annotate each with metadata used by rules.
    ///
    /// Line splitting uses `CharacterSet.newlines`, matching `S101_LineLength`.
    /// Content ending in a newline therefore yields an empty trailing line — rules that
    /// care about that case should inspect the raw content directly (e.g. `M047`).
    public static func scan(_ content: String) -> [ScannedLine] {
        let rawLines = content.components(separatedBy: .newlines)

        let frontmatterRange = frontmatterInteriorRange(lines: rawLines)

        var scanned: [ScannedLine] = []
        scanned.reserveCapacity(rawLines.count)

        for (index, raw) in rawLines.enumerated() {
            let lineNumber = index + 1
            let isBlank = raw.trimmingCharacters(in: .whitespaces).isEmpty
            let isInFrontmatter = frontmatterRange?.contains(index) ?? false
            scanned.append(
                ScannedLine(
                    number: lineNumber,
                    raw: raw,
                    isBlank: isBlank,
                    isInFrontmatter: isInFrontmatter
                )
            )
        }

        return scanned
    }

    /// Zero-indexed range of line indexes *inside* the top YAML frontmatter block, exclusive of delimiters.
    /// Returns `nil` when the file has no frontmatter.
    private static func frontmatterInteriorRange(lines: [String]) -> Range<Int>? {
        guard lines.first == "---" else {
            return nil
        }

        for (index, line) in lines.enumerated() where index > 0 {
            if line == "---" {
                return 1..<index
            }
        }

        return nil
    }
}
