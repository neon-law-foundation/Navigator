import Foundation

/// M032: Lists must be surrounded by blank lines.
///
/// Mirrors markdownlint's MD032 (blanks-around-lists).
public struct M032_BlanksAroundLists: Rule {
    public let code = "M032"
    public let description = "Lists must be surrounded by blank lines"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        for (index, block) in blocks.enumerated() {
            guard case .list = block.kind else { continue }

            if index > 0 {
                let previous = blocks[index - 1]
                if previous.kind != .blank, previous.kind != .frontmatter {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "List is not preceded by a blank line",
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
                            message: "List is not followed by a blank line",
                            line: block.endLine
                        )
                    )
                }
            }
        }
        return violations
    }
}
