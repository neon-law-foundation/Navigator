import Foundation

/// M026: Headings must not end with trailing punctuation.
///
/// Mirrors markdownlint's MD026 (no-trailing-punctuation) with the default punctuation set
/// `.,;:!` plus the matching fullwidth CJK characters. `?` is deliberately excluded — question
/// headings ("What next?") are common and not stylistic offenders.
public struct M026_NoTrailingPunctuation: Rule {
    public let code = "M026"
    public let description = "Headings must not end with trailing punctuation"
    private static let punctuation: Set<Character> = [
        ".", ",", ";", ":", "!",
        "\u{3002}", "\u{FF0C}", "\u{FF1B}", "\u{FF1A}", "\u{FF01}",
    ]

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        for block in blocks {
            guard case .heading(_, _, let text) = block.kind else { continue }
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard let last = trimmed.last else { continue }
            if Self.punctuation.contains(last) {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Heading ends with trailing punctuation",
                        line: block.startLine,
                        context: ["character": String(last)]
                    )
                )
            }
        }
        return violations
    }
}
