import Foundation

/// M031: Fenced code blocks must be surrounded by blank lines.
///
/// Mirrors markdownlint's MD031 (blanks-around-fences).
public struct M031_BlanksAroundFences: Rule {
    public let code = "M031"
    public let description = "Fenced code blocks must be surrounded by blank lines"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        for (index, block) in blocks.enumerated() {
            guard case .fencedCode = block.kind else { continue }

            if index > 0 {
                let previous = blocks[index - 1]
                if previous.kind != .blank, previous.kind != .frontmatter {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Fenced code block is not preceded by a blank line",
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
                            message: "Fenced code block is not followed by a blank line",
                            line: block.endLine
                        )
                    )
                }
            }
        }
        return violations
    }
}
