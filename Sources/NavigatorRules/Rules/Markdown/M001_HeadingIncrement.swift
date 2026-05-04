import Foundation

/// M001: Heading levels must only increase by one at a time.
///
/// Mirrors markdownlint's MD001 (heading-increment). The first heading sets the baseline; each
/// subsequent heading may stay at the same level, decrease by any amount, or increase by exactly 1.
public struct M001_HeadingIncrement: Rule {
    public let code = "M001"
    public let description = "Heading levels must only increment by one"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        var previousLevel: Int?
        for block in blocks {
            guard case .heading(let level, _, _) = block.kind else { continue }
            if let previous = previousLevel, level > previous + 1 {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Heading level jumps from \(previous) to \(level)",
                        line: block.startLine,
                        context: ["previous": "\(previous)", "current": "\(level)"]
                    )
                )
            }
            previousLevel = level
        }
        return violations
    }
}
