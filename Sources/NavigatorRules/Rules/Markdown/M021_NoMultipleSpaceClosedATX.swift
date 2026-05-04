import Foundation

/// M021: Closed ATX headings must have exactly one space between the hash marks and the heading text.
///
/// Mirrors markdownlint's MD021 (no-multiple-space-closed-atx).
public struct M021_NoMultipleSpaceClosedATX: Rule {
    public let code = "M021"
    public let description = "Closed ATX headings must have single spaces around the heading text"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) where !line.isInFrontmatter {
            guard let parts = ATXHeadingParser.parseClosed(line.raw) else { continue }

            let leadingMultiple = parts.content.hasPrefix("  ")
            let trailingMultiple = parts.content.hasSuffix("  ")

            if leadingMultiple || trailingMultiple {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Multiple spaces inside hashes on closed ATX heading",
                        line: line.number
                    )
                )
            }
        }
        return violations
    }
}
