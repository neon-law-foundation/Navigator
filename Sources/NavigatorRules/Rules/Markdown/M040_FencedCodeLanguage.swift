import Foundation

/// M040: Fenced code blocks should specify a language in the info string.
///
/// Mirrors markdownlint's MD040 (fenced-code-language).
public struct M040_FencedCodeLanguage: Rule {
    public let code = "M040"
    public let description = "Fenced code blocks must specify a language"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        for block in blocks {
            guard case .fencedCode(_, let info) = block.kind else { continue }
            // The info string's first whitespace-separated token is the language.
            let language = info.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
            if language.isEmpty {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Fenced code block is missing a language",
                        line: block.startLine
                    )
                )
            }
        }
        return violations
    }
}
