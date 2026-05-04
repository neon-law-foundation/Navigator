import Foundation

/// M028: A blank line inside what appears to be one logical block quote splits it into two.
///
/// Mirrors markdownlint's MD028 (no-blanks-blockquote). Flags the blank block sitting between
/// two block-quote blocks.
public struct M028_NoBlanksBlockquote: Rule {
    public let code = "M028"
    public let description = "Blank lines inside block quotes split them into separate blocks"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        guard blocks.count >= 3 else { return [] }
        for index in 1..<(blocks.count - 1) {
            let previous = blocks[index - 1]
            let current = blocks[index]
            let next = blocks[index + 1]
            if current.kind == .blank, previous.kind == .blockquote, next.kind == .blockquote {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Blank line inside block quote",
                        line: current.startLine
                    )
                )
            }
        }
        return violations
    }
}
