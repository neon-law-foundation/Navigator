import Foundation

/// M022: Headings must be surrounded by blank lines.
///
/// Mirrors markdownlint's MD022 (blanks-around-headings).
public struct M022_BlanksAroundHeadings: Rule {
    public let code = "M022"
    public let description = "Headings must be surrounded by blank lines"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        for (index, block) in blocks.enumerated() {
            guard case .heading = block.kind else { continue }

            if index > 0 {
                let previous = blocks[index - 1]
                if previous.kind != .blank, previous.kind != .frontmatter {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Heading is not preceded by a blank line",
                            line: block.startLine
                        )
                    )
                }
            }

            if index < blocks.count - 1 {
                let next = blocks[index + 1]
                if next.kind != .blank {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Heading is not followed by a blank line",
                            line: block.endLine
                        )
                    )
                }
            }
        }
        return violations
    }
}
