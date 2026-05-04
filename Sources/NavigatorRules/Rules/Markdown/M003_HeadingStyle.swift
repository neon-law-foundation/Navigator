import Foundation

/// M003: All headings in a file must use the same style.
///
/// Mirrors markdownlint's MD003 (heading-style) with the default `style: "consistent"`:
/// the first heading sets the expected style; subsequent headings that differ are flagged.
/// Setext style only supports levels 1 and 2, so when a setext-styled file introduces a
/// deeper heading that heading is permitted to use ATX without being flagged.
public struct M003_HeadingStyle: Rule {
    public let code = "M003"
    public let description = "Headings must use a consistent style"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        var expected: HeadingStyle?
        for block in blocks {
            guard case .heading(let level, let style, _) = block.kind else { continue }
            guard let current = expected else {
                expected = style
                continue
            }
            // Setext can't represent level-3+ headings; allow ATX for those when the baseline is setext.
            if current == .setext, level >= 3, style == .atx { continue }
            if current != style {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Heading style does not match first-heading style",
                        line: block.startLine,
                        context: ["expected": "\(current)", "actual": "\(style)"]
                    )
                )
            }
        }
        return violations
    }
}
