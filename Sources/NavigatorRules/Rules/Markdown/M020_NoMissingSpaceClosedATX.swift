import Foundation

/// M020: Closed ATX headings must have a space between the hash marks and the heading text on both sides.
///
/// Mirrors markdownlint's MD020 (no-missing-space-closed-atx).
public struct M020_NoMissingSpaceClosedATX: Rule {
    public let code = "M020"
    public let description = "Closed ATX headings must have spaces around the heading text"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let codeLines = BlockTokenizer.linesInsideCodeBlocks(content)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) where !line.isInFrontmatter {
            if codeLines.contains(line.number) { continue }
            guard let parts = ATXHeadingParser.parseClosed(line.raw) else { continue }

            let leadingOK = parts.content.first?.isWhitespace ?? false
            let trailingOK = parts.content.last?.isWhitespace ?? false

            if !leadingOK || !trailingOK {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Missing space inside hashes on closed ATX heading",
                        line: line.number
                    )
                )
            }
        }
        return violations
    }
}
