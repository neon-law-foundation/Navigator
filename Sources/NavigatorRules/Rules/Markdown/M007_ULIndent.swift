import Foundation

/// M007: Unordered list items must be indented consistently with their nesting level.
///
/// Mirrors markdownlint's MD007 (ul-indent). A top-level unordered item has no indent; a nested
/// unordered item aligns its marker with its parent's content column. This handles the common
/// case of an unordered sub-list under an ordered parent, whose content column depends on the
/// parent's marker width (e.g. `1. ` → content at column 4, so a `-` child indents by 3).
public struct M007_ULIndent: Rule {
    public let code = "M007"
    public let description = "Unordered list items must be indented consistently with their nesting level"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        var violations: [Violation] = []
        for parsed in ListParser.parseLists(in: content) {
            for item in parsed.items where !item.ordered {
                let expected: Int
                if let parentIndex = item.parentIndex {
                    expected = parsed.items[parentIndex].contentColumn - 1
                } else {
                    expected = 0
                }
                if item.indent != expected {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message:
                                "Unordered list item at depth \(item.depth) expected \(expected) spaces of indent but found \(item.indent)",
                            line: item.line,
                            context: [
                                "expected": "\(expected)",
                                "actual": "\(item.indent)",
                            ]
                        )
                    )
                }
            }
        }
        return violations
    }
}
